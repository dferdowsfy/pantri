import Foundation

// MARK: - Item Status

/// Derived prediction status for a tracked item.
enum ItemStatus: String, Codable, CaseIterable {
    case good       // No action needed — well stocked
    case needSoon   // Likely needed within reminder lead time
    case buyNow     // Predicted purchase date has passed or is today
}

// MARK: - Item Category

enum ItemCategory: String, Codable, CaseIterable, Identifiable {
    case dairy
    case produce
    case bakery
    case household
    case pantry
    case beverages
    case meatSeafood
    case frozen
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .dairy: return "Dairy"
        case .produce: return "Produce"
        case .bakery: return "Bakery"
        case .household: return "Household"
        case .pantry: return "Pantry"
        case .beverages: return "Beverages"
        case .meatSeafood: return "Meat & Seafood"
        case .frozen: return "Frozen"
        case .other: return "Other"
        }
    }

    var emoji: String {
        switch self {
        case .dairy: return "🥛"
        case .produce: return "🥬"
        case .bakery: return "🍞"
        case .household: return "🧹"
        case .pantry: return "🥫"
        case .beverages: return "☕"
        case .meatSeafood: return "🥩"
        case .frozen: return "🧊"
        case .other: return "📦"
        }
    }
}

// MARK: - Reminder Action

/// Action the user took in response to a reminder or prediction card.
enum ReminderAction: String, Codable {
    case bought       // User confirmed they purchased the item
    case notYet       // User says they don't need it yet — pushes prediction out
    case remindLater  // User wants to be reminded again later — no baseline change
    case ignored      // Notification was dismissed without action — neutral signal
}

// MARK: - Purchase Source

/// How a purchase was recorded.
enum PurchaseSource: String, Codable {
    case manual    // User tapped "Bought"
    case receipt   // Detected from a scanned receipt
    case inferred  // System-inferred (future use)
}
