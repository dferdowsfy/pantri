import Foundation

/// Generates friendly, non-precise notification copy for item reminders.
protocol NotificationCopyGenerating {
    func generateBody(for prediction: ItemPrediction) -> String
}

struct NotificationCopyGenerator: NotificationCopyGenerating {

    private let templates: [ItemStatus: [String]] = [
        .buyNow: [
            "You'll likely need %@ soon",
            "Might be time to grab some %@",
            "%@ is probably worth picking up",
            "Running low on %@? Might be time to restock"
        ],
        .needSoon: [
            "%@ may be worth grabbing %@",
            "You'll probably need %@ %@",
            "Heads up — %@ might be needed %@"
        ]
    ]

    func generateBody(for prediction: ItemPrediction) -> String {
        let name = prediction.itemName.lowercased()

        switch prediction.status {
        case .buyNow:
            let options = templates[.buyNow] ?? []
            let template = options.randomElement() ?? "You'll likely need %@ soon"
            return String(format: template, name)

        case .needSoon:
            let timeDesc = dayDescription(prediction.daysUntilNeeded)
            let options = templates[.needSoon] ?? []
            let template = options.randomElement() ?? "%@ may be worth grabbing %@"
            return String(format: template, prediction.itemName, timeDesc)

        case .good:
            return "You're good on \(name) for now"
        }
    }

    private func dayDescription(_ days: Int?) -> String {
        guard let days else { return "soon" }
        switch days {
        case 0:     return "today"
        case 1:     return "tomorrow"
        case 2:     return "in a couple days"
        case 3...5: return "this week"
        default:    return "soon"
        }
    }
}
