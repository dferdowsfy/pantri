import Foundation
import SwiftData

@Model
final class ConsumptionProfile {
    @Attribute(.unique) var id: UUID

    /// Baseline typical consumption interval in days (from defaults JSON or user override).
    var baselineDays: Double

    /// Current estimated days between purchases, adapted from purchase history + baseline.
    var currentEstimatedDays: Double

    /// How confident the system is in the prediction (0.0–1.0).
    var confidenceScore: Double

    /// Whether this item spoils (affects urgency language and thresholds).
    var isPerishable: Bool

    /// Multiplier for adjusting consumption based on household size. e.g. 0.8 means per-person usage scales sublinearly.
    var householdSizeModifier: Double

    /// How many days before predicted need to send a reminder.
    var reminderLeadDays: Int

    /// Min days in the typical range (from baseline).
    var typicalDaysMin: Double

    /// Max days in the typical range (from baseline).
    var typicalDaysMax: Double

    var lastUpdated: Date

    @Relationship(inverse: \TrackedItem.consumptionProfile)
    var trackedItem: TrackedItem?

    init(
        id: UUID = UUID(),
        baselineDays: Double,
        currentEstimatedDays: Double? = nil,
        confidenceScore: Double = 0.3,
        isPerishable: Bool = true,
        householdSizeModifier: Double = 1.0,
        reminderLeadDays: Int = 2,
        typicalDaysMin: Double? = nil,
        typicalDaysMax: Double? = nil,
        lastUpdated: Date = .now
    ) {
        self.id = id
        self.baselineDays = baselineDays
        self.currentEstimatedDays = currentEstimatedDays ?? baselineDays
        self.confidenceScore = confidenceScore
        self.isPerishable = isPerishable
        self.householdSizeModifier = householdSizeModifier
        self.reminderLeadDays = reminderLeadDays
        self.typicalDaysMin = typicalDaysMin ?? (baselineDays * 0.7)
        self.typicalDaysMax = typicalDaysMax ?? (baselineDays * 1.3)
        self.lastUpdated = lastUpdated
    }
}
