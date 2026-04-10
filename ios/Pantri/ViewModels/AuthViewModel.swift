import SwiftUI

@Observable
final class AuthViewModel {
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isLoading = false
    var errorMessage: String?
    var showResetAlert = false
    var resetEmail = ""

    private let auth: AuthProvider

    init(auth: AuthProvider) {
        self.auth = auth
    }

    // MARK: - Validation

    var isLoginValid: Bool {
        !email.trimmingCharacters(in: .whitespaces).isEmpty && password.count >= 6
    }

    var isSignUpValid: Bool {
        isLoginValid && password == confirmPassword
    }

    // MARK: - Actions

    @MainActor
    func signIn() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.signIn(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func signUp() async {
        isLoading = true
        errorMessage = nil
        do {
            try await auth.signUp(email: email.trimmingCharacters(in: .whitespaces), password: password)
        } catch {
            errorMessage = friendlyError(error)
        }
        isLoading = false
    }

    @MainActor
    func sendPasswordReset() async {
        guard !resetEmail.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        do {
            try await auth.sendPasswordReset(email: resetEmail.trimmingCharacters(in: .whitespaces))
            errorMessage = nil
        } catch {
            errorMessage = friendlyError(error)
        }
    }

    // MARK: - Helpers

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        switch nsError.code {
        case 17008: return "Please enter a valid email address."
        case 17009: return "Incorrect password. Try again."
        case 17011: return "No account found with that email."
        case 17007: return "An account with that email already exists."
        case 17026: return "Password must be at least 6 characters."
        case 17010: return "Too many attempts. Please try again later."
        default: return nsError.localizedDescription
        }
    }
}
