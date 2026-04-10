import SwiftUI
import SwiftData

// MARK: - Notifications

extension Notification.Name {
    static let pantriInventoryChanged = Notification.Name("pantriInventoryChanged")
    static let pantriSwitchToTab = Notification.Name("pantriSwitchToTab")
    static let pantriOpenShoppingList = Notification.Name("pantriOpenShoppingList")
}

// MARK: - Design Tokens
// Calm, premium palette with full dark-mode support

extension Color {

    // MARK: Backgrounds

    /// Main screen background — warm off-white / near-black
    static let pantriBackground = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.07, green: 0.07, blue: 0.08, alpha: 1)
            : UIColor(red: 0.965, green: 0.957, blue: 0.945, alpha: 1)
    })

    /// Card / row surface — white / elevated dark gray
    static let pantriSurface = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.14, blue: 0.15, alpha: 1)
            : UIColor.white
    })

    // MARK: Brand greens (same both modes)

    static let pantriGreen     = Color(red: 0.18, green: 0.52, blue: 0.32)
    static let pantriGreenMid  = Color(red: 0.16, green: 0.44, blue: 0.28)
    static let pantriGreenDark = Color(red: 0.10, green: 0.32, blue: 0.20)

    /// Light mint — tinted in light, subtle dark-green tint in dark
    static let pantriGreenLight = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.14, green: 0.22, blue: 0.16, alpha: 1)
            : UIColor(red: 0.92, green: 0.96, blue: 0.93, alpha: 1)
    })

    // MARK: Text hierarchy

    /// Primary text — near-black / near-white
    static let pantriText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.95, green: 0.95, blue: 0.96, alpha: 1)
            : UIColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1)
    })

    /// Secondary text
    static let pantriSecondaryText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.62, green: 0.62, blue: 0.64, alpha: 1)
            : UIColor(red: 0.55, green: 0.55, blue: 0.57, alpha: 1)
    })

    /// Tertiary text
    static let pantriTertiaryText = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 0.45, green: 0.45, blue: 0.47, alpha: 1)
            : UIColor(red: 0.72, green: 0.72, blue: 0.73, alpha: 1)
    })

    // MARK: Legacy aliases

    static let pantriOrange       = pantriBackground
    static let pantriOrangeAccent = pantriGreen

    /// Subtle card border — visible in light, invisible in dark
    static let pantriCardBorder = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 1, green: 1, blue: 1, alpha: 0.06)
            : UIColor(red: 0, green: 0, blue: 0, alpha: 0.10)
    })

    // MARK: Urgency indicators (same both modes — semantic)

    static let urgencyRed    = Color(red: 0.90, green: 0.28, blue: 0.24)
    static let urgencyYellow = Color(red: 0.88, green: 0.72, blue: 0.18)
    static let urgencyGreen  = Color(red: 0.28, green: 0.68, blue: 0.42)

    // MARK: FAB glow

    static let pantriGlow = Color(red: 0.18, green: 0.52, blue: 0.32).opacity(0.30)
}
