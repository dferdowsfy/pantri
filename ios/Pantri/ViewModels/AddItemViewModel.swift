import SwiftUI
import SwiftData

@Observable
final class AddItemViewModel {
    var name: String = ""
    var selectedCategory: ItemCategory = .other
    var baselineDaysOverride: String = ""
    var isPerishable: Bool = true
    var isSaving = false
    var errorMessage: String?
    var didSave = false

    private let itemRepo: ItemRepositoryProtocol

    init(itemRepo: ItemRepositoryProtocol = SwiftDataItemRepository()) {
        self.itemRepo = itemRepo
    }

    var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func autoSetPerishable(for category: ItemCategory) {
        switch category {
        case .dairy, .produce, .bakery, .meatSeafood:
            isPerishable = true
        case .pantry, .household, .frozen, .beverages, .other:
            isPerishable = false
        }
    }

    @MainActor
    func save(context: ModelContext) {
        guard isValid else {
            errorMessage = "Please enter an item name"
            return
        }

        isSaving = true
        errorMessage = nil

        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let baselineDays = Double(baselineDaysOverride) ?? defaultBaselineDays(for: selectedCategory)

        let item = TrackedItem(
            name: trimmedName,
            canonicalName: trimmedName.lowercased(),
            category: selectedCategory
        )

        let profile = ConsumptionProfile(
            baselineDays: baselineDays,
            confidenceScore: 0.2, // Low confidence for manually added items
            isPerishable: isPerishable,
            reminderLeadDays: isPerishable ? 2 : 4
        )

        item.consumptionProfile = profile

        do {
            try itemRepo.save(item, context: context)
            didSave = true
        } catch {
            errorMessage = "Could not save item: \(error.localizedDescription)"
        }

        isSaving = false
    }

    private func defaultBaselineDays(for category: ItemCategory) -> Double {
        switch category {
        case .dairy, .produce, .bakery, .meatSeafood: return 7
        case .beverages: return 14
        case .pantry, .frozen: return 21
        case .household: return 30
        case .other: return 14
        }
    }
}
