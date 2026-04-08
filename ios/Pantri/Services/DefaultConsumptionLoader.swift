import Foundation
import SwiftData

// MARK: - Consumption Default DTO (matches JSON shape)

struct ConsumptionDefault: Codable {
    let canonicalName: String
    let aliases: [String]
    let category: String
    let typicalDaysMin: Double
    let typicalDaysMax: Double
    let urgencyThresholdDays: Int
    let householdSizeModifier: Double
    let confidenceLevel: Double
    let isPerishable: Bool
    let reminderLeadDays: Int
}

// MARK: - Protocol

protocol DefaultConsumptionLoading {
    func loadDefaults(into context: ModelContext) throws
}

// MARK: - Implementation

struct DefaultConsumptionLoader: DefaultConsumptionLoading {
    private let itemRepo: ItemRepositoryProtocol

    init(itemRepo: ItemRepositoryProtocol = SwiftDataItemRepository()) {
        self.itemRepo = itemRepo
    }

    /// Loads bundled consumption_defaults.json and creates TrackedItem + ConsumptionProfile
    /// records for each item. Idempotent — skips items that already exist by canonical name.
    func loadDefaults(into context: ModelContext) throws {
        let defaults = try loadDefaultsFromBundle()

        for entry in defaults {
            // Skip if item already exists
            if let _ = try itemRepo.findByCanonicalName(entry.canonicalName, context: context) {
                continue
            }

            let category = ItemCategory(rawValue: entry.category) ?? .other
            let baselineDays = (entry.typicalDaysMin + entry.typicalDaysMax) / 2.0

            let item = TrackedItem(
                name: entry.canonicalName.capitalized,
                canonicalName: entry.canonicalName,
                category: category,
                aliases: entry.aliases
            )

            let profile = ConsumptionProfile(
                baselineDays: baselineDays,
                confidenceScore: entry.confidenceLevel,
                isPerishable: entry.isPerishable,
                householdSizeModifier: entry.householdSizeModifier,
                reminderLeadDays: entry.reminderLeadDays,
                typicalDaysMin: entry.typicalDaysMin,
                typicalDaysMax: entry.typicalDaysMax
            )

            item.consumptionProfile = profile

            context.insert(item)
        }

        try context.save()
    }

    // MARK: - Private

    private func loadDefaultsFromBundle() throws -> [ConsumptionDefault] {
        guard let url = Bundle.main.url(forResource: "consumption_defaults", withExtension: "json") else {
            throw LoaderError.fileNotFound
        }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([ConsumptionDefault].self, from: data)
    }

    enum LoaderError: Error, LocalizedError {
        case fileNotFound

        var errorDescription: String? {
            switch self {
            case .fileNotFound:
                return "consumption_defaults.json not found in app bundle"
            }
        }
    }
}
