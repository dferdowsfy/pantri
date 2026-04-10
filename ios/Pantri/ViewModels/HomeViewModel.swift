import SwiftUI
import SwiftData

@Observable
final class HomeViewModel {
    var homeData: HomeScreenData?
    var isLoading = true
    var greeting: String = DateHelpers.greeting()
    var errorMessage: String?

    private let homeScreenService: HomeScreenServiceProtocol
    private let learningService: LearningServiceProtocol
    private let notificationService: NotificationService
    private let consumptionLoader: DefaultConsumptionLoading

    init(
        homeScreenService: HomeScreenServiceProtocol = HomeScreenService(),
        learningService: LearningServiceProtocol = LearningService(),
        notificationService: NotificationService = NotificationService(),
        consumptionLoader: DefaultConsumptionLoading = DefaultConsumptionLoader()
    ) {
        self.homeScreenService = homeScreenService
        self.learningService = learningService
        self.notificationService = notificationService
        self.consumptionLoader = consumptionLoader
    }

    var headlineText: String {
        "\(greeting)."
    }

    var subtitleText: String {
        guard let data = homeData else { return "Loading your inventory..." }

        let urgentCount = data.needSoon.count
        if urgentCount == 0 {
            return "Everything looks good."
        } else {
            return "\(urgentCount) item\(urgentCount == 1 ? " needs" : "s need") attention."
        }
    }

    /// Combined list for the merged "What to buy" section, sorted by urgency.
    /// Excludes items purchased in the last 24 hours.
    var whatToBuyItems: [ItemSummary] {
        guard let data = homeData else { return [] }
        let combined = data.needSoon + data.thisWeek
        let filtered = combined.filter { !recentlyBoughtIds.contains($0.id) }
        return filtered.sorted { ($0.daysUntilNeeded ?? 99) < ($1.daysUntilNeeded ?? 99) }
    }

    /// IDs of items bought in last 24h — refreshed alongside homeData
    private var recentlyBoughtIds: Set<UUID> = []

    @MainActor
    func loadFirstLaunchIfNeeded(context: ModelContext, appState: AppState) {
        guard !appState.hasCompletedFirstLaunch else { return }
        do {
            try consumptionLoader.loadDefaults(into: context)
            appState.markFirstLaunchComplete()
        } catch {
            errorMessage = "Could not load default items: \(error.localizedDescription)"
        }
    }

    @MainActor
    func refresh(context: ModelContext) {
        isLoading = true
        errorMessage = nil
        greeting = DateHelpers.greeting()

        do {
            homeData = try homeScreenService.deriveHomeScreen(context: context)
            // Find items bought in the last 24 hours
            let purchaseRepo = SwiftDataPurchaseRepository()
            let recentPurchases = try purchaseRepo.fetchRecentPurchases(limit: 50, context: context)
            let cutoff = Date.now.addingTimeInterval(-24 * 3600)
            recentlyBoughtIds = Set(
                recentPurchases
                    .filter { $0.purchasedAt >= cutoff }
                    .compactMap { $0.trackedItem?.id }
            )
        } catch {
            errorMessage = "Could not load predictions: \(error.localizedDescription)"
        }

        isLoading = false

        // Reschedule notifications in the background
        Task {
            try? await notificationService.rescheduleAll(context: context)
        }
    }

    @MainActor
    func handleBought(itemId: UUID, context: ModelContext) {
        guard let item = findItem(id: itemId, context: context) else {
            errorMessage = "Item not found"
            return
        }
        do {
            try learningService.recordBought(item: item, context: context)
            let impact = UINotificationFeedbackGenerator()
            impact.notificationOccurred(.success)
            refresh(context: context)
        } catch {
            errorMessage = "Could not record purchase: \(error.localizedDescription)"
        }
    }

    @MainActor
    func handleNotYet(itemId: UUID, context: ModelContext) {
        guard let item = findItem(id: itemId, context: context) else { return }
        do {
            try learningService.recordNotYet(item: item, context: context)
            refresh(context: context)
        } catch {
            errorMessage = "Could not record feedback: \(error.localizedDescription)"
        }
    }

    @MainActor
    func handleSnooze(itemId: UUID, context: ModelContext) {
        guard let item = findItem(id: itemId, context: context) else {
            errorMessage = "Item not found"
            return
        }
        do {
            try learningService.recordRemindLater(item: item, snoozeHours: 72, context: context)
            let impact = UIImpactFeedbackGenerator(style: .medium)
            impact.impactOccurred()
            refresh(context: context)
        } catch {
            errorMessage = "Could not snooze item: \(error.localizedDescription)"
        }
    }

    @MainActor
    func handleRemindLater(itemId: UUID, context: ModelContext) {
        guard let item = findItem(id: itemId, context: context) else { return }
        do {
            try learningService.recordRemindLater(item: item, snoozeHours: 24, context: context)
            refresh(context: context)
        } catch {
            errorMessage = "Could not snooze reminder: \(error.localizedDescription)"
        }
    }

    // MARK: - Private

    private func findItem(id: UUID, context: ModelContext) -> TrackedItem? {
        let descriptor = FetchDescriptor<TrackedItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try? context.fetch(descriptor).first
    }
}
