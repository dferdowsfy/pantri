import Foundation
import SwiftData

// MARK: - Extracted Receipt Item DTO

struct ExtractedReceiptItemDTO {
    let rawText: String
    let normalizedName: String
    let confidence: Double
}

// MARK: - Receipt Match Result

struct ReceiptMatchResult {
    let matched: [(item: TrackedItem, extractedName: String)]
    let unmatched: [ExtractedReceiptItemDTO]
}

// MARK: - Protocol

protocol ReceiptProcessingServiceProtocol {
    /// Save a captured receipt image and return the ReceiptCapture record.
    func captureReceipt(imageData: Data, context: ModelContext) throws -> ReceiptCapture
    /// Process a receipt capture using the OCR provider, extract items, and match.
    func processReceipt(_ capture: ReceiptCapture, context: ModelContext) async throws -> ReceiptMatchResult
    /// Record purchase events for matched items.
    func recordMatches(_ matches: [(item: TrackedItem, extractedName: String)], context: ModelContext) throws
}

// MARK: - Implementation

struct ReceiptProcessingService: ReceiptProcessingServiceProtocol {
    private let ocrProvider: OCRProviderProtocol
    private let itemRepo: ItemRepositoryProtocol
    private let learningService: LearningServiceProtocol

    init(
        ocrProvider: OCRProviderProtocol = StubOCRProvider(),
        itemRepo: ItemRepositoryProtocol = SwiftDataItemRepository(),
        learningService: LearningServiceProtocol = LearningService()
    ) {
        self.ocrProvider = ocrProvider
        self.itemRepo = itemRepo
        self.learningService = learningService
    }

    func captureReceipt(imageData: Data, context: ModelContext) throws -> ReceiptCapture {
        // Store the image file in Documents directory
        let fileName = "receipt_\(UUID().uuidString).jpg"
        guard let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw ReceiptError.storageUnavailable
        }

        let receiptsDir = docsDir.appendingPathComponent("receipts", isDirectory: true)
        try FileManager.default.createDirectory(at: receiptsDir, withIntermediateDirectories: true)

        let filePath = receiptsDir.appendingPathComponent(fileName)
        try imageData.write(to: filePath)

        let capture = ReceiptCapture(imageFilePath: "receipts/\(fileName)")
        context.insert(capture)
        try context.save()

        return capture
    }

    func processReceipt(_ capture: ReceiptCapture, context: ModelContext) async throws -> ReceiptMatchResult {
        // Load image data from file
        guard let imageURL = capture.imageURL else {
            throw ReceiptError.imageNotFound
        }
        let imageData = try Data(contentsOf: imageURL)

        // Extract items via OCR provider
        let extracted = try await ocrProvider.extractItems(from: imageData)

        // Save extracted items to the capture
        for dto in extracted {
            let extractedItem = ExtractedReceiptItem(
                rawText: dto.rawText,
                normalizedName: dto.normalizedName,
                confidence: dto.confidence
            )
            extractedItem.receiptCapture = capture
            context.insert(extractedItem)
        }
        capture.processed = true
        try context.save()

        // Match extracted items to tracked items
        return try matchExtractedItems(extracted, context: context)
    }

    func recordMatches(_ matches: [(item: TrackedItem, extractedName: String)], context: ModelContext) throws {
        for (item, _) in matches {
            try learningService.recordReceiptPurchase(item: item, purchaseDate: .now, context: context)
        }
    }

    // MARK: - Private Matching

    private func matchExtractedItems(_ items: [ExtractedReceiptItemDTO], context: ModelContext) throws -> ReceiptMatchResult {
        var matched: [(item: TrackedItem, extractedName: String)] = []
        var unmatched: [ExtractedReceiptItemDTO] = []

        for extracted in items {
            if let item = try findMatchingItem(for: extracted.normalizedName, context: context) {
                matched.append((item: item, extractedName: extracted.normalizedName))
            } else {
                unmatched.append(extracted)
            }
        }

        return ReceiptMatchResult(matched: matched, unmatched: unmatched)
    }

    /// Fuzzy-matches an extracted name to a tracked item using canonical name, aliases, and substring matching.
    private func findMatchingItem(for name: String, context: ModelContext) throws -> TrackedItem? {
        let lower = name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Exact match on canonical name or alias
        if let item = try itemRepo.findByNameOrAlias(lower, context: context) {
            return item
        }

        // 2. Substring / contains match — check if any tracked item name appears in the extracted text
        let allItems = try itemRepo.fetchActive(context: context)
        for item in allItems {
            if lower.contains(item.canonicalName) || item.canonicalName.contains(lower) {
                return item
            }
            for alias in item.aliases {
                if lower.contains(alias.lowercased()) || alias.lowercased().contains(lower) {
                    return item
                }
            }
        }

        return nil
    }

    enum ReceiptError: Error, LocalizedError {
        case storageUnavailable
        case imageNotFound

        var errorDescription: String? {
            switch self {
            case .storageUnavailable: return "Could not access app storage for receipt images"
            case .imageNotFound: return "Receipt image file not found"
            }
        }
    }
}
