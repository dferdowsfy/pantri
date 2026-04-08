import Foundation
import SwiftData

@Model
final class ReceiptCapture {
    @Attribute(.unique) var id: UUID

    /// File path relative to the app's Documents directory (not raw image data to avoid DB bloat).
    var imageFilePath: String

    var capturedAt: Date
    var processed: Bool
    var createdAt: Date

    @Relationship(deleteRule: .cascade)
    var extractedItems: [ExtractedReceiptItem]?

    init(
        id: UUID = UUID(),
        imageFilePath: String,
        capturedAt: Date = .now,
        processed: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.imageFilePath = imageFilePath
        self.capturedAt = capturedAt
        self.processed = processed
        self.createdAt = createdAt
    }

    /// Full URL to the receipt image in the Documents directory.
    var imageURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docs?.appendingPathComponent(imageFilePath)
    }
}
