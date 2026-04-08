import Foundation
import SwiftData

// MARK: - Sync Provider

/// Optional cloud sync provider for backing up and syncing data across devices.
protocol SyncProviderProtocol {
    var lastSyncDate: Date? { get }
    func pushItems(context: ModelContext) async throws
    func pullItems(context: ModelContext) async throws
}

/// Stub sync provider — no-op.
struct StubSyncProvider: SyncProviderProtocol {
    var lastSyncDate: Date? { nil }

    func pushItems(context: ModelContext) async throws {
        // No-op: cloud sync not implemented
    }

    func pullItems(context: ModelContext) async throws {
        // No-op
    }
}
