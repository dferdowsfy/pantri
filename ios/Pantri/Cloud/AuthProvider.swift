import Foundation

// MARK: - Auth Provider

/// Optional authentication provider for cloud sync.
protocol AuthProviderProtocol {
    var isAuthenticated: Bool { get }
    var currentUserId: String? { get }
    func signIn(email: String, password: String) async throws
    func signOut() async throws
}

/// Stub auth provider — always unauthenticated.
struct StubAuthProvider: AuthProviderProtocol {
    var isAuthenticated: Bool { false }
    var currentUserId: String? { nil }

    func signIn(email: String, password: String) async throws {
        // No-op: cloud auth not implemented
    }

    func signOut() async throws {
        // No-op
    }
}
