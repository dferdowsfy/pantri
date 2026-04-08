import XCTest
import SwiftData
@testable import Pantri

final class PredictionServiceTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!
    private var sut: PredictionService!

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
        sut = PredictionService()
    }

    override func tearDown() {
        container = nil
        context = nil
        sut = nil
    }

    // MARK: - Baseline Only (No Purchases)

    func testPredictWithBaselineOnly_returnsGoodStatus() throws {
        let item = makeItem(baselineDays: 14, reminderLeadDays: 2)
        context.insert(item)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        // With no purchases, item should be predicted as needing buying in ~30% of baseline
        XCTAssertNotNil(prediction.predictedNextPurchase)
        XCTAssertEqual(prediction.itemName, "Test Item")
        // Confidence should be low with no data
        XCTAssertLessThan(prediction.confidenceScore, 0.5)
    }

    func testPredictWithNoProfile_returnsLowConfidence() throws {
        let item = TrackedItem(name: "No Profile Item")
        // No consumption profile attached
        context.insert(item)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        XCTAssertEqual(prediction.status, .good)
        XCTAssertEqual(prediction.confidenceScore, 0.1)
        XCTAssertNil(prediction.predictedNextPurchase)
    }

    // MARK: - With Purchase History

    func testPredictWithRecentPurchase_statusIsGood() throws {
        let item = makeItem(baselineDays: 7, reminderLeadDays: 2)
        context.insert(item)

        // Purchase 1 day ago
        let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-86400))
        event.trackedItem = item
        context.insert(event)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        XCTAssertEqual(prediction.status, .good)
        XCTAssertGreaterThan(prediction.daysUntilNeeded ?? 0, 2)
    }

    func testPredictWithOldPurchase_statusIsBuyNow() throws {
        let item = makeItem(baselineDays: 7, reminderLeadDays: 2)
        context.insert(item)

        // Purchase 10 days ago (overdue for a 7-day item)
        let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-10 * 86400))
        event.trackedItem = item
        context.insert(event)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        XCTAssertEqual(prediction.status, .buyNow)
    }

    func testPredictWithNeedSoonTiming() throws {
        let item = makeItem(baselineDays: 7, reminderLeadDays: 2)
        context.insert(item)

        // Purchase 6 days ago (should need soon for a 7-day baseline with 2-day lead)
        let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(-6 * 86400))
        event.trackedItem = item
        context.insert(event)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        XCTAssertEqual(prediction.status, .needSoon)
    }

    // MARK: - Blending

    func testBlendingWithMultiplePurchases() throws {
        let item = makeItem(baselineDays: 10, reminderLeadDays: 2)
        context.insert(item)

        // 5 purchases, each 7 days apart (actual avg = 7, baseline = 10)
        for i in 0..<5 {
            let event = PurchaseEvent(purchasedAt: Date.now.addingTimeInterval(Double(-35 + i * 7) * 86400))
            event.trackedItem = item
            context.insert(event)
        }
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        // With 5 purchases, blend should heavily favor actual (7 days)
        // Expected: ~0.15 * 10 + 0.85 * 7 = 7.45
        XCTAssertNotNil(prediction.daysUntilNeeded)
        // Confidence should be moderate-high with 5 purchases
        XCTAssertGreaterThan(prediction.confidenceScore, 0.5)
    }

    // MARK: - Explanation

    func testExplanationUsesNonPreciseLanguage() throws {
        let item = makeItem(baselineDays: 7, reminderLeadDays: 2)
        context.insert(item)
        try context.save()

        let prediction = try sut.predict(for: item, context: context)

        // Should use soft language, never exact quantities
        let explanation = prediction.explanation.lowercased()
        XCTAssertFalse(explanation.contains("remaining"))
        XCTAssertFalse(explanation.contains("units"))
        XCTAssertFalse(explanation.contains("% left"))
    }

    // MARK: - PredictAll

    func testPredictAllReturnsAllActiveItems() throws {
        let item1 = makeItem(name: "Milk", baselineDays: 7, reminderLeadDays: 2)
        let item2 = makeItem(name: "Eggs", baselineDays: 14, reminderLeadDays: 2)
        let inactiveItem = makeItem(name: "Inactive", baselineDays: 7, reminderLeadDays: 2)
        inactiveItem.isActive = false

        context.insert(item1)
        context.insert(item2)
        context.insert(inactiveItem)
        try context.save()

        let predictions = try sut.predictAll(context: context)

        XCTAssertEqual(predictions.count, 2)
    }

    // MARK: - Helpers

    private func makeItem(name: String = "Test Item", baselineDays: Double, reminderLeadDays: Int) -> TrackedItem {
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
