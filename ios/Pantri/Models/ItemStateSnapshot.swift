import Foundation
import SwiftData

/// Point-in-time snapshot of a tracked item's predicted state.
/// Used to power the home screen and notification decisions.
@Model
final class ItemStateSnapshot {
    @Attribute(.unique) var id: UUID
    var computedAt: Date
    var statusRaw: String
    var predictedNextPurchase: Date?
    var confidenceScore: Double
    var explanation: String

    @Relationship(inverse: \TrackedItem.stateSnapshots)
    var trackedItem: TrackedItem?

    var status: ItemStatus {
        get { ItemStatus(rawValue: statusRaw) ?? .good }
        set { statusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        computedAt: Date = .now,
        status: ItemStatus,
        predictedNextPurchase: Date? = nil,
        confidenceScore: Double = 0.3,
        explanation: String = ""
    ) {
        self.id = id
        self.computedAt = computedAt
        self.statusRaw = status.rawValue
        self.predictedNextPurchase = predictedNextPurchase
        self.confidenceScore = confidenceScore
        self.explanation = explanation
    }
}
