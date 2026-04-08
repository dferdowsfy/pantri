import Foundation

// MARK: - Remote Config Provider

/// Optional remote configuration for overriding default consumption profiles.
protocol RemoteConfigProviderProtocol {
    func fetchDefaults() async throws -> [ConsumptionDefault]?
}

/// Stub remote config provider — returns nil (use bundled defaults).
struct StubRemoteConfigProvider: RemoteConfigProviderProtocol {
    func fetchDefaults() async throws -> [ConsumptionDefault]? {
        nil // Use bundled defaults
    }
}
