import SwiftUI
import SwiftData
import FirebaseCore

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // FirebaseApp.configure() called in PantriApp.init() to ensure
        // it runs before @State properties that depend on Auth.
        return true
    }
}

@main
struct PantriApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate

    @State private var appState = AppState()
    @State private var authProvider: AuthProvider
    @State private var authVM: AuthViewModel?
    @State private var showSplash = true
    @State private var showLogin = true

    init() {
        FirebaseApp.configure()
        _authProvider = State(initialValue: AuthProvider())
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if authProvider.isAuthenticated {
                        MainTabView()
                            .environment(appState)
                            .onAppear {
                                Task {
                                    await appState.performFirstLaunchSetupIfNeeded()
                                }
                            }
                    } else {
                        authContent
                    }
                }

                if showSplash {
                    SplashView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                withAnimation(.easeOut(duration: 0.35)) {
                                    showSplash = false
                                }
                            }
                        }
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

    @ViewBuilder
    private var authContent: some View {
        let vm = authVM ?? {
            let v = AuthViewModel(auth: authProvider)
            Task { @MainActor in authVM = v }
            return v
        }()

        if showLogin {
            LoginView(vm: vm, onSwitchToSignUp: {
                withAnimation(.easeInOut(duration: 0.25)) { showLogin = false }
            })
            .transition(.move(edge: .leading).combined(with: .opacity))
        } else {
            SignUpView(vm: vm, onSwitchToLogin: {
                withAnimation(.easeInOut(duration: 0.25)) { showLogin = true }
            })
            .transition(.move(edge: .trailing).combined(with: .opacity))
        }
    }
}
