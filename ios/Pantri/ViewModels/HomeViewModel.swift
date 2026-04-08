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
        guard let data = homeData else { return "\(greeting)." }

        if data.needSoon.isEmpty && data.thisWeek.isEmpty {
            return "\(greeting). Pantry looks calm."
        } else if !data.needSoon.isEmpty {
            return "\(greeting). A few items to check on."
        } else {
            return "\(greeting). Looking mostly good."
        }
    }

    var subtitleText: String {
        guard let data = homeData else { return "Loading your inventory..." }

        if data.needSoon.isEmpty {
            return "Your inventory is managed and predictable today."
        } else {
            let count = data.needSoon.count
            return "\(count) item\(count == 1 ? "" : "s") may need attention."
        }
    }

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
        guard let item = findItem(id: itemId, context: context) else { return }
        do {
            try learningService.recordBought(item: item, context: context)
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
