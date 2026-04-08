import Foundation

/// Helpers for common date operations used throughout the prediction engine.
enum DateHelpers {

    /// Returns the number of days between two dates (can be negative).
    static func daysBetween(_ start: Date, _ end: Date) -> Int {
        Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0
    }

    /// Returns a human-readable relative time string.
    static func relativeDescription(daysFromNow days: Int) -> String {
        switch days {
        case ..<0:     return "overdue"
        case 0:        return "today"
        case 1:        return "tomorrow"
        case 2...6:    return "in \(days) days"
        case 7:        return "in about a week"
        case 8...13:   return "in about a week and a half"
        case 14:       return "in about two weeks"
        case 15...20:  return "in a couple weeks"
        case 21...27:  return "in about three weeks"
        default:       return "in about a month"
        }
    }

    /// Returns a time-of-day greeting.
    static func greeting() -> String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Good evening"
        }
    }
}
