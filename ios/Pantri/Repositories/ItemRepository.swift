import Foundation
import SwiftData

// MARK: - Protocol

protocol ItemRepositoryProtocol {
    func fetchAll(context: ModelContext) throws -> [TrackedItem]
    func fetchActive(context: ModelContext) throws -> [TrackedItem]
    func fetchByCategory(_ category: ItemCategory, context: ModelContext) throws -> [TrackedItem]
    func findByCanonicalName(_ name: String, context: ModelContext) throws -> TrackedItem?
    func findByNameOrAlias(_ query: String, context: ModelContext) throws -> TrackedItem?
    func save(_ item: TrackedItem, context: ModelContext) throws
    func delete(_ item: TrackedItem, context: ModelContext) throws
}

// MARK: - SwiftData Implementation

struct SwiftDataItemRepository: ItemRepositoryProtocol {

    func fetchAll(context: ModelContext) throws -> [TrackedItem] {
        let descriptor = FetchDescriptor<TrackedItem>(
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetchActive(context: ModelContext) throws -> [TrackedItem] {
        let descriptor = FetchDescriptor<TrackedItem>(
            predicate: #Predicate { $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func fetchByCategory(_ category: ItemCategory, context: ModelContext) throws -> [TrackedItem] {
        let raw = category.rawValue
        let descriptor = FetchDescriptor<TrackedItem>(
            predicate: #Predicate { $0.categoryRaw == raw && $0.isActive },
            sortBy: [SortDescriptor(\.name)]
        )
        return try context.fetch(descriptor)
    }

    func findByCanonicalName(_ name: String, context: ModelContext) throws -> TrackedItem? {
        let lower = name.lowercased()
        let descriptor = FetchDescriptor<TrackedItem>(
            predicate: #Predicate { $0.canonicalName == lower }
        )
        return try context.fetch(descriptor).first
    }

    func findByNameOrAlias(_ query: String, context: ModelContext) throws -> TrackedItem? {
        let lower = query.lowercased()

        // First try canonical name exact match
        if let item = try findByCanonicalName(lower, context: context) {
            return item
        }

        // Then search through aliases of all items
        let allItems = try fetchAll(context: context)
        return allItems.first { item in
            item.aliases.contains { $0.lowercased() == lower }
        }
    }

    func save(_ item: TrackedItem, context: ModelContext) throws {
        item.updatedAt = .now
        context.insert(item)
        try context.save()
    }

    func delete(_ item: TrackedItem, context: ModelContext) throws {
        context.delete(item)
        try context.save()
    }
}
