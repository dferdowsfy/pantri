import SwiftUI
import SwiftData

@main
struct PantriApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environment(appState)
                .onAppear {
                    Task {
                        await appState.performFirstLaunchSetupIfNeeded()
                    }
                }
        }
        .modelContainer(for: [
            UserProfile.self,
            HouseholdProfile.self,
            TrackedItem.self,
            ConsumptionProfile.self,
            PurchaseEvent.self,
            ReminderEvent.self,
            ItemStateSnapshot.self,
            ReceiptCapture.self,
            ExtractedReceiptItem.self
        ])
    }
}
