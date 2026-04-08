import SwiftUI
import SwiftData
import PhotosUI

@Observable
final class ReceiptViewModel {
    var selectedPhotoItem: PhotosPickerItem?
    var capturedImage: Data?
    var isProcessing = false
    var matchResult: ReceiptMatchResult?
    var errorMessage: String?
    var showResults = false

    private let receiptService: ReceiptProcessingServiceProtocol

    init(receiptService: ReceiptProcessingServiceProtocol = ReceiptProcessingService()) {
        self.receiptService = receiptService
    }

    @MainActor
    func processSelectedPhoto(context: ModelContext) async {
        guard let photoItem = selectedPhotoItem else { return }

        isProcessing = true
        errorMessage = nil

        do {
            guard let data = try await photoItem.loadTransferable(type: Data.self) else {
                errorMessage = "Could not load the selected image"
                isProcessing = false
                return
            }

            capturedImage = data
            let capture = try receiptService.captureReceipt(imageData: data, context: context)
            matchResult = try await receiptService.processReceipt(capture, context: context)
            showResults = true
        } catch {
            errorMessage = "Receipt processing failed: \(error.localizedDescription)"
        }

        isProcessing = false
    }

    @MainActor
    func confirmMatches(context: ModelContext) {
        guard let result = matchResult else { return }

        do {
            try receiptService.recordMatches(result.matched, context: context)
        } catch {
            errorMessage = "Could not record purchases: \(error.localizedDescription)"
        }
    }
}
