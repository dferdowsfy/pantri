import XCTest
import SwiftData
@testable import Pantri

final class LearningServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: LearningService!

    override func setUp() async throws {
        let schema = Schema([
            TrackedItem.self,
            ConsumptionProfile.self,
            PurchaseEvent.self,
            ReminderEvent.self,
            ItemStateSnapshot.self,
            ReceiptCapture.self,
            ExtractedReceiptItem.self,
            UserProfile.self,
            HouseholdProfile.self
        ])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
        sut = LearningService()
    }

    override func tearDown() {
        container = nil
        context = nil
        sut = nil
    }

    // MARK: - Record Bought

    func testRecordBought_createsPurchaseEvent() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        try sut.recordBought(item: item, context: context)

        let events = try context.fetch(FetchDescriptor<PurchaseEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.source, .manual)
    }

    func testRecordBought_createsReminderEvent() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        try sut.recordBought(item: item, context: context)

        let events = try context.fetch(FetchDescriptor<ReminderEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.action, .bought)
    }

    // MARK: - Record Not Yet

    func testRecordNotYet_pushesEstimateOut() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        let originalEstimate = item.consumptionProfile!.currentEstimatedDays

        try sut.recordNotYet(item: item, context: context)

        XCTAssertGreaterThan(item.consumptionProfile!.currentEstimatedDays, originalEstimate)
    }

    func testRecordNotYet_decreasesConfidence() throws {
        let item = makeItem(baselineDays: 7)
        item.consumptionProfile!.confidenceScore = 0.5
        context.insert(item)
        try context.save()

        try sut.recordNotYet(item: item, context: context)

        XCTAssertLessThan(item.consumptionProfile!.confidenceScore, 0.5)
    }

    func testRecordNotYet_createsReminderEvent() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        try sut.recordNotYet(item: item, context: context)

        let events = try context.fetch(FetchDescriptor<ReminderEvent>())
        XCTAssertEqual(events.first?.action, .notYet)
    }

    // MARK: - Record Remind Later

    func testRecordRemindLater_doesNotChangeBaseline() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        let originalEstimate = item.consumptionProfile!.currentEstimatedDays

        try sut.recordRemindLater(item: item, snoozeHours: 24, context: context)

        XCTAssertEqual(item.consumptionProfile!.currentEstimatedDays, originalEstimate)
    }

    func testRecordRemindLater_createsSnoozedReminderEvent() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        try sut.recordRemindLater(item: item, snoozeHours: 24, context: context)

        let events = try context.fetch(FetchDescriptor<ReminderEvent>())
        XCTAssertEqual(events.first?.action, .remindLater)
        XCTAssertNotNil(events.first?.snoozedUntil)
    }

    // MARK: - Record Ignored

    func testRecordIgnored_doesNotChangeBaseline() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        let originalEstimate = item.consumptionProfile!.currentEstimatedDays
        let originalConfidence = item.consumptionProfile!.confidenceScore

        try sut.recordIgnored(item: item, context: context)

        XCTAssertEqual(item.consumptionProfile!.currentEstimatedDays, originalEstimate)
        XCTAssertEqual(item.consumptionProfile!.confidenceScore, originalConfidence)
    }

    // MARK: - Record Receipt Purchase

    func testRecordReceiptPurchase_createsReceiptSourceEvent() throws {
        let item = makeItem(baselineDays: 7)
        context.insert(item)
        try context.save()

        try sut.recordReceiptPurchase(item: item, purchaseDate: .now, context: context)

        let events = try context.fetch(FetchDescriptor<PurchaseEvent>())
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.source, .receipt)
    }

    // MARK: - Interval Update with Multiple Purchases

    func testMultipleBought_updatesEstimatedInterval() throws {
        let item = makeItem(baselineDays: 14)
        context.insert(item)

        // Simulate 3 purchases spaced 7 days apart
        for i in 0..<3 {
            let event = PurchaseEvent(
                purchasedAt: Date.now.addingTimeInterval(Double(-21 + i * 7) * 86400),
                source: .manual
            )
            event.trackedItem = item
            context.insert(event)
        }
        try context.save()

        // Record another "bought" — this should update the interval
        try sut.recordBought(item: item, context: context)

        let profile = item.consumptionProfile!
        // With baseline=14 and actual ~7, the blended estimate should shift toward 7
        XCTAssertLessThan(profile.currentEstimatedDays, 14)
    }

    // MARK: - Helpers

    private func makeItem(baselineDays: Double) -> TrackedItem {
        let item = TrackedItem(name: "Test Item", category: .dairy)
        let profile = ConsumptionProfile(
            baselineDays: baselineDays,
            confidenceScore: 0.3,
            isPerishable: true,
            reminderLeadDays: 2
        )
        item.consumptionProfile = profile
        return item
    }
}
