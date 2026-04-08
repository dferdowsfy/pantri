import Foundation
import SwiftData

// MARK: - Protocol

protocol LearningServiceProtocol {
    /// User tapped "Bought" — record purchase, recalculate interval, increase confidence.
    func recordBought(item: TrackedItem, context: ModelContext) throws
    /// User tapped "Not yet" — push prediction later, record correction.
    func recordNotYet(item: TrackedItem, context: ModelContext) throws
    /// User tapped "Remind later" — snooze without changing baseline.
    func recordRemindLater(item: TrackedItem, snoozeHours: Int, context: ModelContext) throws
    /// Notification was ignored — neutral signal.
    func recordIgnored(item: TrackedItem, context: ModelContext) throws
    /// Item detected on a receipt — same as bought but source = receipt.
    func recordReceiptPurchase(item: TrackedItem, purchaseDate: Date, context: ModelContext) throws
}

// MARK: - Implementation

struct LearningService: LearningServiceProtocol {
    private let purchaseRepo: PurchaseRepositoryProtocol
    private let reminderRepo: ReminderRepositoryProtocol

    init(
        purchaseRepo: PurchaseRepositoryProtocol = SwiftDataPurchaseRepository(),
        reminderRepo: ReminderRepositoryProtocol = SwiftDataReminderRepository()
    ) {
        self.purchaseRepo = purchaseRepo
        self.reminderRepo = reminderRepo
    }

    func recordBought(item: TrackedItem, context: ModelContext) throws {
        // 1. Record the purchase event
        let event = PurchaseEvent(source: .manual)
        try purchaseRepo.recordPurchase(event, for: item, context: context)

        // 2. Record the reminder action
        let reminderEvent = ReminderEvent(scheduledAt: .now, action: .bought, respondedAt: .now)
        try reminderRepo.scheduleReminder(reminderEvent, for: item, context: context)

        // 3. Update the consumption profile
        try updateEstimatedInterval(for: item, context: context)
    }

    func recordNotYet(item: TrackedItem, context: ModelContext) throws {
        // Record the correction
        let reminderEvent = ReminderEvent(scheduledAt: .now, action: .notYet, respondedAt: .now)
        try reminderRepo.scheduleReminder(reminderEvent, for: item, context: context)

        // Push the estimated interval out by ~18% — user says they don't need it yet
        guard let profile = item.consumptionProfile else { return }
        let pushFactor = 1.18
        profile.currentEstimatedDays = min(
            profile.currentEstimatedDays * pushFactor,
            profile.typicalDaysMax * 1.5 // Don't push beyond 1.5x the max typical range
        )
        // Slightly reduce confidence since our prediction was early
        profile.confidenceScore = max(profile.confidenceScore - 0.05, 0.1)
        profile.lastUpdated = .now
        try context.save()
    }

    func recordRemindLater(item: TrackedItem, snoozeHours: Int = 24, context: ModelContext) throws {
        // Record the snooze — does NOT change the baseline
        let snoozedUntil = Date.now.addingTimeInterval(Double(snoozeHours) * 3600)
        let reminderEvent = ReminderEvent(
            scheduledAt: .now,
            action: .remindLater,
            respondedAt: .now,
            snoozedUntil: snoozedUntil
        )
        try reminderRepo.scheduleReminder(reminderEvent, for: item, context: context)
        // No baseline change — the user just wants to be reminded later
    }

    func recordIgnored(item: TrackedItem, context: ModelContext) throws {
        // Weak/neutral signal — just record it, no baseline change
        let reminderEvent = ReminderEvent(scheduledAt: .now, action: .ignored, respondedAt: .now)
        try reminderRepo.scheduleReminder(reminderEvent, for: item, context: context)
    }

    func recordReceiptPurchase(item: TrackedItem, purchaseDate: Date, context: ModelContext) throws {
        // Same as bought, but with receipt source and specific date
        let event = PurchaseEvent(purchasedAt: purchaseDate, source: .receipt)
        try purchaseRepo.recordPurchase(event, for: item, context: context)

        // Update the consumption profile
        try updateEstimatedInterval(for: item, context: context)
    }

    // MARK: - Private

    /// Recalculates the item's estimated consumption interval from purchase history.
    private func updateEstimatedInterval(for item: TrackedItem, context: ModelContext) throws {
        guard let profile = item.consumptionProfile else { return }

        let count = try purchaseRepo.purchaseCount(for: item, context: context)
        let actualAverage = try purchaseRepo.averageInterval(for: item, context: context)

        guard let actualAverage, count >= 2 else {
            // Not enough data to update — keep current estimate
            profile.lastUpdated = .now
            try context.save()
            return
        }

        // Blend baseline with actual data (same logic as PredictionService)
        let baselineWeight: Double
        switch count {
        case 2:     baselineWeight = 0.70
        case 3:     baselineWeight = 0.50
        case 4:     baselineWeight = 0.30
        case 5...7: baselineWeight = 0.15
        default:    baselineWeight = 0.10
        }

        profile.currentEstimatedDays = (profile.baselineDays * baselineWeight) + (actualAverage * (1.0 - baselineWeight))

        // Increase confidence with more data
        profile.confidenceScore = min(profile.confidenceScore + 0.05, 0.9)
        profile.lastUpdated = .now
        try context.save()
    }
}
