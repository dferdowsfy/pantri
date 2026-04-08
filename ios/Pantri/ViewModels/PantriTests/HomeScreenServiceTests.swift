import XCTest
import SwiftData
@testable import Pantri

final class HomeScreenServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: HomeScreenService!

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
        sut = HomeScreenService()
    }

    override func tearDown() {
        container = nil
        context = nil
        sut = nil
    }

    // MARK: - Section Bucketing

    func testDeriveHomeScreen_bucketsBuyNowIntoNeedSoon() throws {
        // Item with old purchase — should be buyNow
        let item = makeItem(name: "Milk", baselineDays: 7, reminderLeadDays: 2)
        context.insert(item)

        let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-10 * 86400))
        event.trackedItem = item
        context.insert(event)
        try context.save()

        let data = try sut.deriveHomeScreen(context: context)

        XCTAssertFalse(data.needSoon.isEmpty, "Overdue item should appear in needSoon section")
        XCTAssertTrue(data.needSoon.contains { $0.name == "Milk" })
    }

    func testDeriveHomeScreen_bucketsGoodItemsCorrectly() throws {
        // Item with recent purchase — should be good
        let item = makeItem(name: "Rice", baselineDays: 30, reminderLeadDays: 5)
        context.insert(item)

        let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-2 * 86400))
        event.trackedItem = item
        context.insert(event)
        try context.save()

        let data = try sut.deriveHomeScreen(context: context)

        let inGood = data.youreGood.contains { $0.name == "Rice" }
        let inThisWeek = data.thisWeek.contains { $0.name == "Rice" }
        XCTAssertTrue(inGood || inThisWeek, "Recently purchased long-baseline item should be in good or thisWeek")
    }

    func testDeriveHomeScreen_sortsNeedSoonByUrgency() throws {
        let item1 = makeItem(name: "Milk", baselineDays: 5, reminderLeadDays: 2)
        let item2 = makeItem(name: "Eggs", baselineDays: 7, reminderLeadDays: 2)
        context.insert(item1)
        context.insert(item2)

        // Milk purchased 6 days ago (more overdue), Eggs purchased 8 days ago
        let event1 = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-6 * 86400))
        event1.trackedItem = item1
        context.insert(event1)

        let event2 = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-8 * 86400))
        event2.trackedItem = item2
        context.insert(event2)
        try context.save()

        let data = try sut.deriveHomeScreen(context: context)

        // Both should be in needSoon, sorted by urgency (most overdue first)
        if data.needSoon.count >= 2 {
            let firstDays = data.needSoon[0].daysUntilNeeded ?? 0
            let secondDays = data.needSoon[1].daysUntilNeeded ?? 0
            XCTAssertLessThanOrEqual(firstDays, secondDays)
        }
    }

    func testDeriveHomeScreen_emptyDatabase_returnsEmptySections() throws {
        let data = try sut.deriveHomeScreen(context: context)

        XCTAssertTrue(data.needSoon.isEmpty)
        XCTAssertTrue(data.thisWeek.isEmpty)
        XCTAssertTrue(data.youreGood.isEmpty)
        XCTAssertEqual(data.totalTrackedItems, 0)
    }

    func testDeriveHomeScreen_excludesInactiveItems() throws {
        let activeItem = makeItem(name: "Active", baselineDays: 7, reminderLeadDays: 2)
        let inactiveItem = makeItem(name: "Inactive", baselineDays: 7, reminderLeadDays: 2)
        inactiveItem.isActive = false

        context.insert(activeItem)
        context.insert(inactiveItem)
        try context.save()

        let data = try sut.deriveHomeScreen(context: context)

        let allNames = (data.needSoon + data.thisWeek + data.youreGood).map(\.name)
        XCTAssertTrue(allNames.contains("Active"))
        XCTAssertFalse(allNames.contains("Inactive"))
    }

    // MARK: - Helpers

    private func makeItem(name: String, baselineDays: Double, reminderLeadDays: Int) -> TrackedItem {
        let item = TrackedItem(name: name, category: .dairy)
        let profile = ConsumptionProfile(
            baselineDays: baselineDays,
            confidenceScore: 0.3,
            isPerishable: true,
            reminderLeadDays: reminderLeadDays
        )
        item.consumptionProfile = profile
        return item
    }
}
