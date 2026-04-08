import Foundation
import SwiftData

@Model
final class TrackedItem {
    @Attribute(.unique) var id: UUID
    var name: String
    var canonicalName: String
    var categoryRaw: String
    var imageURL: String?
    var isActive: Bool
    var householdId: UUID?
    var aliases: [String]
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade)
    var consumptionProfile: ConsumptionProfile?

    @Relationship(deleteRule: .cascade)
    var purchaseEvents: [PurchaseEvent]?

    @Relationship(deleteRule: .cascade)
    var reminderEvents: [ReminderEvent]?

    @Relationship(deleteRule: .cascade)
    var stateSnapshots: [ItemStateSnapshot]?

    var category: ItemCategory {
        get { ItemCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        name: String,
        canonicalName: String? = nil,
        category: ItemCategory = .other,
        imageURL: String? = nil,
        isActive: Bool = true,
        householdId: UUID? = nil,
        aliases: [String] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.canonicalName = canonicalName ?? name.lowercased()
        self.categoryRaw = category.rawValue
        self.imageURL = imageURL
        self.isActive = isActive
        self.householdId = householdId
        self.aliases = aliases
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
