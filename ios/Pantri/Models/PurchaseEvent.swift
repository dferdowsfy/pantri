import Foundation
import SwiftData

@Model
final class PurchaseEvent {
    @Attribute(.unique) var id: UUID
    var purchasedAt: Date
    var sourceRaw: String
    var notes: String?
    var createdAt: Date

    @Relationship(inverse: \TrackedItem.purchaseEvents)
    var trackedItem: TrackedItem?

    var source: PurchaseSource {
        get { PurchaseSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        purchasedAt: Date = .now,
        source: PurchaseSource = .manual,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.purchasedAt = purchasedAt
        self.sourceRaw = source.rawValue
        self.notes = notes
        self.createdAt = createdAt
    }
}
