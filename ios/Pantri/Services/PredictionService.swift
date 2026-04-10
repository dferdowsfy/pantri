import Foundation
import SwiftData

// MARK: - Prediction Output

/// Lightweight result of a repurchase prediction for a single item.
struct ItemPrediction {
    let itemId: UUID
    let itemName: String
    let category: ItemCategory
    let predictedNextPurchase: Date?
    let daysUntilNeeded: Int?
    let confidenceScore: Double
    let status: ItemStatus
    let explanation: String
    let emoji: String
}

// MARK: - Protocol

protocol PredictionServiceProtocol {
    func predict(for item: TrackedItem, context: ModelContext) throws -> ItemPrediction
    func predictAll(context: ModelContext) throws -> [ItemPrediction]
}

// MARK: - Implementation

/// Lightweight weighted-average prediction engine.
/// Blends baseline consumption rules with actual purchase history.
/// No ML — just simple interval math that improves with usage.
struct PredictionService: PredictionServiceProtocol {
    private let purchaseRepo: PurchaseRepositoryProtocol

    init(purchaseRepo: PurchaseRepositoryProtocol = SwiftDataPurchaseRepository()) {
        self.purchaseRepo = purchaseRepo
    }

    func predict(for item: TrackedItem, context: ModelContext) throws -> ItemPrediction {
        guard let profile = item.consumptionProfile else {
            // No profile — return a low-confidence "good" prediction
            return ItemPrediction(
                itemId: item.id,
                itemName: item.name,
                category: item.category,
                predictedNextPurchase: nil,
                daysUntilNeeded: nil,
                confidenceScore: 0.1,
                status: .good,
                explanation: "Not enough data to predict when you'll need \(item.name)",
                emoji: item.category.emoji
            )
        }

        let purchaseCount = try purchaseRepo.purchaseCount(for: item, context: context)
        let actualAverage = try purchaseRepo.averageInterval(for: item, context: context)
        let lastPurchase = try purchaseRepo.lastPurchaseDate(for: item, context: context)

        // Blend baseline with actual purchase intervals based on data volume
        let estimatedDays = blendedEstimate(
            baseline: profile.currentEstimatedDays,
            actual: actualAverage,
            purchaseCount: purchaseCount
        )

        // Confidence increases with more data
        let confidence = computeConfidence(
            baseConfidence: profile.confidenceScore,
            purchaseCount: purchaseCount
        )

        // Predict next purchase date from last purchase + estimated interval
        let (predictedDate, daysUntil) = computeNextPurchaseDate(
            lastPurchase: lastPurchase,
            estimatedDays: estimatedDays
        )

        // Derive status based on days until needed and reminder lead time
        let status = deriveStatus(
            daysUntil: daysUntil,
            reminderLeadDays: profile.reminderLeadDays
        )

        // Generate human-friendly explanation
        let explanation = generateExplanation(
            itemName: item.name,
            status: status,
            daysUntil: daysUntil,
            confidence: confidence,
            isPerishable: profile.isPerishable
        )

        return ItemPrediction(
            itemId: item.id,
            itemName: item.name,
            category: item.category,
            predictedNextPurchase: predictedDate,
            daysUntilNeeded: daysUntil,
            confidenceScore: confidence,
            status: status,
            explanation: explanation,
            emoji: item.category.emoji
        )
    }

    func predictAll(context: ModelContext) throws -> [ItemPrediction] {
        let itemRepo = SwiftDataItemRepository()
        let items = try itemRepo.fetchActive(context: context)
        let now = Date.now
        // Filter out items that are currently snoozed
        let unsnoozed = items.filter { item in
            guard let reminders = item.reminderEvents else { return true }
            let latestSnooze = reminders
                .filter { $0.action == .remindLater && $0.snoozedUntil != nil }
                .max(by: { ($0.snoozedUntil ?? .distantPast) < ($1.snoozedUntil ?? .distantPast) })
            guard let snoozedUntil = latestSnooze?.snoozedUntil else { return true }
            return now >= snoozedUntil
        }
        return try unsnoozed.map { try predict(for: $0, context: context) }
    }

    // MARK: - Private Helpers

    /// Weighted blend of baseline and actual purchase intervals.
    /// More data → more weight on actual behavior.
    private func blendedEstimate(baseline: Double, actual: Double?, purchaseCount: Int) -> Double {
        guard let actual, purchaseCount >= 2 else {
            return baseline // Not enough data, use baseline only
        }

        let baselineWeight: Double
        switch purchaseCount {
        case 2:    baselineWeight = 0.70
        case 3:    baselineWeight = 0.50
        case 4:    baselineWeight = 0.30
        case 5...7: baselineWeight = 0.15
        default:   baselineWeight = 0.10 // 8+ purchases — trust actual history
        }

        return (baseline * baselineWeight) + (actual * (1.0 - baselineWeight))
    }

    /// Confidence grows with more purchase events, capped at 0.9 (never claim certainty).
    private func computeConfidence(baseConfidence: Double, purchaseCount: Int) -> Double {
        let dataBonus = min(Double(purchaseCount) * 0.08, 0.5)
        return min(baseConfidence + dataBonus, 0.9)
    }

    /// Predicts next purchase date and days until needed.
    private func computeNextPurchaseDate(lastPurchase: Date?, estimatedDays: Double) -> (Date?, Int?) {
        guard let lastPurchase else {
            // No purchase history — suggest buying in ~estimatedDays from now
            // (This handles brand-new items)
            let predicted = Date.now.addingTimeInterval(estimatedDays * 0.3 * 86400)
            let daysUntil = max(0, Calendar.current.dateComponents([.day], from: .now, to: predicted).day ?? 0)
            return (predicted, daysUntil)
        }

        let predicted = lastPurchase.addingTimeInterval(estimatedDays * 86400)
        let daysUntil = Calendar.current.dateComponents([.day], from: .now, to: predicted).day ?? 0
        return (predicted, daysUntil)
    }

    /// Maps days-until-needed to a status bucket.
    private func deriveStatus(daysUntil: Int?, reminderLeadDays: Int) -> ItemStatus {
        guard let daysUntil else { return .good }

        if daysUntil <= 0 {
            return .buyNow
        } else if daysUntil <= reminderLeadDays {
            return .needSoon
        } else {
            return .good
        }
    }

    /// Generates natural-language explanation. Avoids fake precision.
    private func generateExplanation(
        itemName: String,
        status: ItemStatus,
        daysUntil: Int?,
        confidence: Double,
        isPerishable: Bool
    ) -> String {
        let name = itemName.lowercased()

        guard let daysUntil else {
            return "Not enough data to predict when you'll need \(name)"
        }

        switch status {
        case .buyNow:
            if confidence > 0.6 {
                return "You'll likely need \(name) soon"
            } else {
                return "\(itemName) might be worth picking up"
            }

        case .needSoon:
            if daysUntil == 1 {
                return "\(itemName) may be worth grabbing tomorrow"
            } else {
                return "You'll probably need \(name) in about \(daysUntil) days"
            }

        case .good:
            if daysUntil <= 7 {
                return "\(itemName) is likely fine for a few more days"
            } else if daysUntil <= 14 {
                return "You're good on \(name) for about a week"
            } else {
                return "You're good on \(name) for a while"
            }
        }
    }
}
