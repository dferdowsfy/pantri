import SwiftUI
import SwiftData

// MARK: - Design Tokens
// Warm nature palette: soft orange (Anthropic-ish) + fresh green shapes

extension Color {
    static let pantriOrange      = Color(red: 0.98, green: 0.93, blue: 0.87)  // warm cream-orange bg
    static let pantriOrangeAccent = Color(red: 0.95, green: 0.55, blue: 0.20) // vivid orange CTA
    static let pantriGreen       = Color(red: 0.25, green: 0.62, blue: 0.38)  // fresh green
    static let pantriGreenLight  = Color(red: 0.85, green: 0.95, blue: 0.88)  // light mint card bg
    static let pantriGreenDark   = Color(red: 0.10, green: 0.38, blue: 0.22)  // dark pill nav bg
    static let pantriText        = Color(red: 0.12, green: 0.14, blue: 0.16)  // near-black text
}
