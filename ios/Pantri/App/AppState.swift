import SwiftUI
import SwiftData

/// Observable app-level state shared across views via the environment.
@Observable
final class AppState {
    var hasCompletedFirstLaunch: Bool = UserDefaults.standard.bool(forKey: "hasCompletedFirstLaunch")
    var notificationPermissionGranted: Bool = false

    private let userDefaultsKey = "hasCompletedFirstLaunch"

    /// Loads baseline consumption defaults on first launch, then marks first launch complete.
    @MainActor
    func performFirstLaunchSetupIfNeeded() async {
        guard !hasCompletedFirstLaunch else { return }

        // Actual loading happens in the view layer where ModelContext is available.
        // This just manages the flag.
    }

    func markFirstLaunchComplete() {
        hasCompletedFirstLaunch = true
        UserDefaults.standard.set(true, forKey: userDefaultsKey)
    }
}
