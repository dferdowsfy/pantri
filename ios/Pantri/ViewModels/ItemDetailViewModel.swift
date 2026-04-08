import SwiftUI
import SwiftData

@Observable
final class ItemDetailViewModel {
    var item: TrackedItem?
    var prediction: ItemPrediction?
    var purchaseHistory: [PurchaseEvent] = []
    var isLoading = false
    var errorMessage: String?

    private let predictionService: PredictionServiceProtocol
    private let learningService: LearningServiceProtocol
    private let purchaseRepo: PurchaseRepositoryProtocol

    init(
        predictionService: PredictionServiceProtocol = PredictionService(),
        learningService: LearningServiceProtocol = LearningService(),
        purchaseRepo: PurchaseRepositoryProtocol = SwiftDataPurchaseRepository()
    ) {
        self.predictionService = predictionService
        self.learningService = learningService
        self.purchaseRepo = purchaseRepo
    }

    @MainActor
    func load(item: TrackedItem, context: ModelContext) {
        self.item = item
        isLoading = true

        do {
            prediction = try predictionService.predict(for: item, context: context)
            purchaseHistory = try purchaseRepo.fetchForItem(item, since: nil, context: context)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    @MainActor
    func handleBought(context: ModelContext) {
        guard let item else { return }
        do {
            try learningService.recordBought(item: item, context: context)
            load(item: item, context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func handleNotYet(context: ModelContext) {
        guard let item else { return }
        do {
            try learningService.recordNotYet(item: item, context: context)
            load(item: item, context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func handleRemindLater(context: ModelContext) {
        guard let item else { return }
        do {
            try learningService.recordRemindLater(item: item, snoozeHours: 24, context: context)
            load(item: item, context: context)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
