import Foundation
import SwiftData

// MARK: - Protocol

protocol PurchaseRepositoryProtocol {
    func recordPurchase(_ event: PurchaseEvent, for item: TrackedItem, context: ModelContext) throws
    func fetchForItem(_ item: TrackedItem, since: Date?, context: ModelContext) throws -> [PurchaseEvent]
    func fetchRecentPurchases(limit: Int, context: ModelContext) throws -> [PurchaseEvent]
    func averageInterval(for item: TrackedItem, context: ModelContext) throws -> Double?
    func lastPurchaseDate(for item: TrackedItem, context: ModelContext) throws -> Date?
    func purchaseCount(for item: TrackedItem, context: ModelContext) throws -> Int
}

// MARK: - SwiftData Implementation

struct SwiftDataPurchaseRepository: PurchaseRepositoryProtocol {

    func recordPurchase(_ event: PurchaseEvent, for item: TrackedItem, context: ModelContext) throws {
        event.trackedItem = item
        context.insert(event)
        try context.save()
    }

    func fetchForItem(_ item: TrackedItem, since: Date? = nil, context: ModelContext) throws -> [PurchaseEvent] {
        let itemId = item.id
        let descriptor: FetchDescriptor<PurchaseEvent>

        if let since {
            descriptor = FetchDescriptor<PurchaseEvent>(
                predicate: #Predicate { event in
                    event.trackedItem?.id == itemId && event.purchasedAt >= since
                },
                sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)]
            )
        } else {
            descriptor = FetchDescriptor<PurchaseEvent>(
                predicate: #Predicate { event in
                    event.trackedItem?.id == itemId
                },
                sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)]
            )
        }

        return try context.fetch(descriptor)
    }

    func fetchRecentPurchases(limit: Int, context: ModelContext) throws -> [PurchaseEvent] {
        var descriptor = FetchDescriptor<PurchaseEvent>(
            sortBy: [SortDescriptor(\.purchasedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        return try context.fetch(descriptor)
    }

    func averageInterval(for item: TrackedItem, context: ModelContext) throws -> Double? {
        let events = try fetchForItem(item, context: context)
        guard events.count >= 2 else { return nil }

        let sorted = events.sorted { $0.purchasedAt < $1.purchasedAt }
        var intervals: [Double] = []

        for i in 1..<sorted.count {
            let interval = sorted[i].purchasedAt.timeIntervalSince(sorted[i - 1].purchasedAt)
            let days = interval / 86400.0
            if days > 0 { intervals.append(days) }
        }

        guard !intervals.isEmpty else { return nil }
        return intervals.reduce(0, +) / Double(intervals.count)
    }

    func lastPurchaseDate(for item: TrackedItem, context: ModelContext) throws -> Date? {
        let events = try fetchForItem(item, context: context)
        return events.first?.purchasedAt // Already sorted descending
    }

    func purchaseCount(for item: TrackedItem, context: ModelContext) throws -> Int {
        let events = try fetchForItem(item, context: context)
        return events.count
    }
}
