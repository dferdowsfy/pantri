import Foundation
import SwiftData

@Model
final class ExtractedReceiptItem {
    @Attribute(.unique) var id: UUID
    var rawText: String
    var normalizedName: String
    var matchedTrackedItemId: UUID?
    var confidence: Double
    var createdAt: Date

    @Relationship(inverse: \ReceiptCapture.extractedItems)
    var receiptCapture: ReceiptCapture?

    init(
        id: UUID = UUID(),
        rawText: String,
        normalizedName: String,
        matchedTrackedItemId: UUID? = nil,
        confidence: Double = 0.0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.rawText = rawText
        self.normalizedName = normalizedName
        self.matchedTrackedItemId = matchedTrackedItemId
        self.confidence = confidence
        self.createdAt = createdAt
    }
}
