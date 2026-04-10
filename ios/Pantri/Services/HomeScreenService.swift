import Foundation
import SwiftData

// MARK: - Home Screen Data

/// View-ready data for the home screen's three sections.
struct HomeScreenData {
    let needSoon: [ItemSummary]   // buyNow + needSoon items, sorted by urgency
    let thisWeek: [ItemSummary]   // Predicted within 7 days but not yet urgent
    let youreGood: [ItemSummary]  // Everything else

    var totalTrackedItems: Int {
        needSoon.count + thisWeek.count + youreGood.count
    }
}

/// Lightweight view model for a single item in a home screen section.
struct ItemSummary: Identifiable {
    let id: UUID
    let name: String
    let category: ItemCategory
    let emoji: String
    let status: ItemStatus
    let daysUntilNeeded: Int?
    let explanation: String
    let confidenceScore: Double

    /// Short subtitle for compact list rows (e.g. "In ~2 days")
    var subtitle: String {
        guard let days = daysUntilNeeded else { return "No prediction yet" }
        if days <= 0 { return "Needed now" }
        if days == 1 { return "In ~1 day" }
        return "In ~\(days) days"
    }

    /// Urgency level based on days until needed
    enum UrgencyLevel {
        case urgent   // <1 day
        case soon     // 1–3 days
        case stable   // 3+ days
    }

    var urgency: UrgencyLevel {
        guard let days = daysUntilNeeded else { return .stable }
        if days < 1 { return .urgent }
        if days <= 3 { return .soon }
        return .stable
    }
}

// MARK: - Protocol

protocol HomeScreenServiceProtocol {
    func deriveHomeScreen(context: ModelContext) throws -> HomeScreenData
}

// MARK: - Implementation

struct HomeScreenService: HomeScreenServiceProtocol {
    private let predictionService: PredictionServiceProtocol

    init(predictionService: PredictionServiceProtocol = PredictionService()) {
        self.predictionService = predictionService
    }

    func deriveHomeScreen(context: ModelContext) throws -> HomeScreenData {
        let predictions = try predictionService.predictAll(context: context)

        var needSoon: [ItemSummary] = []
        var thisWeek: [ItemSummary] = []
        var youreGood: [ItemSummary] = []

        for prediction in predictions {
            let summary = ItemSummary(
                id: prediction.itemId,
                name: prediction.itemName,
                category: prediction.category,
                emoji: prediction.emoji,
                status: prediction.status,
                daysUntilNeeded: prediction.daysUntilNeeded,
                explanation: prediction.explanation,
                confidenceScore: prediction.confidenceScore
            )

            switch prediction.status {
            case .buyNow, .needSoon:
                needSoon.append(summary)
            case .good:
                if let days = prediction.daysUntilNeeded, days <= 7 {
                    thisWeek.append(summary)
                } else {
                    youreGood.append(summary)
                }
            }
        }

        // Sort by urgency — most urgent first
        needSoon.sort { ($0.daysUntilNeeded ?? 0) < ($1.daysUntilNeeded ?? 0) }
        thisWeek.sort { ($0.daysUntilNeeded ?? 0) < ($1.daysUntilNeeded ?? 0) }
        youreGood.sort { $0.name < $1.name }

        return HomeScreenData(
            needSoon: needSoon,
            thisWeek: thisWeek,
            youreGood: youreGood
        )
    }
}
