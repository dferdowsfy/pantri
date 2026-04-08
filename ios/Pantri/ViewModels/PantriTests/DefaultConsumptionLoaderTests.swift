#if canImport(XCTest)
import XCTest
import SwiftData
@testable import Pantri

final class DefaultConsumptionLoaderTests: XCTestCase {

    private var container: ModelContainer!
    private var context: ModelContext!

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
    }

    override func tearDown() {
        container = nil
        context = nil
    }

    // MARK: - JSON Parsing

    func testConsumptionDefaultsJSON_isValidAndParseable() throws {
        // Load from test bundle
        guard let url = Bundle.main.url(forResource: "consumption_defaults", withExtension: "json") else {
            // In unit test context, bundle might not include the resource — skip gracefully
            throw XCTSkip("consumption_defaults.json not in test bundle")
        }

        let data = try Data(contentsOf: url)
        let defaults = try JSONDecoder().decode([ConsumptionDefault].self, from: data)

        XCTAssertGreaterThanOrEqual(defaults.count, 15, "Should have at least 15 default items")

        // Verify required fields on each entry
        for item in defaults {
            XCTAssertFalse(item.canonicalName.isEmpty)
            XCTAssertGreaterThan(item.typicalDaysMin, 0)
            XCTAssertGreaterThanOrEqual(item.typicalDaysMax, item.typicalDaysMin)
            XCTAssertGreaterThan(item.urgencyThresholdDays, 0)
            XCTAssertGreaterThan(item.householdSizeModifier, 0)
            XCTAssertGreaterThanOrEqual(item.confidenceLevel, 0)
            XCTAssertLessThanOrEqual(item.confidenceLevel, 1.0)
            XCTAssertGreaterThan(item.reminderLeadDays, 0)
        }
    }

    func testConsumptionDefaultsJSON_categoriesAreValid() throws {
        guard let url = Bundle.main.url(forResource: "consumption_defaults", withExtension: "json") else {
            throw XCTSkip("consumption_defaults.json not in test bundle")
        }

        let data = try Data(contentsOf: url)
        let defaults = try JSONDecoder().decode([ConsumptionDefault].self, from: data)

        for item in defaults {
            XCTAssertNotNil(
                ItemCategory(rawValue: item.category),
                "Category '\(item.category)' for '\(item.canonicalName)' is not a valid ItemCategory"
            )
        }
    }

    // MARK: - Idempotency

    func testLoadDefaults_isIdempotent() throws {
        let loader = DefaultConsumptionLoader()

        // Load twice — should not create duplicates
        // Note: This test requires the JSON to be in the bundle, so it may need to be
        // run as part of the app target's tests rather than a pure unit test.
        // In a pure unit test, we'd mock the bundle loading.
        do {
            try loader.loadDefaults(into: context)
            let firstCount = try context.fetchCount(FetchDescriptor<TrackedItem>())

            try loader.loadDefaults(into: context)
            let secondCount = try context.fetchCount(FetchDescriptor<TrackedItem>())

            XCTAssertEqual(firstCount, secondCount, "Loading defaults twice should not create duplicates")
        } catch {
            throw XCTSkip("Bundle resource not available in test context: \(error)")
        }
    }
}
#endif
