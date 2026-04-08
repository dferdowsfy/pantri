import Foundation
import SwiftData

// MARK: - Protocol

protocol ReminderRepositoryProtocol {
    func scheduleReminder(_ event: ReminderEvent, for item: TrackedItem, context: ModelContext) throws
    func fetchPending(context: ModelContext) throws -> [ReminderEvent]
    func fetchForItem(_ item: TrackedItem, context: ModelContext) throws -> [ReminderEvent]
    func recordAction(_ action: ReminderAction, for event: ReminderEvent, context: ModelContext) throws
}

// MARK: - SwiftData Implementation

struct SwiftDataReminderRepository: ReminderRepositoryProtocol {

    func scheduleReminder(_ event: ReminderEvent, for item: TrackedItem, context: ModelContext) throws {
        event.trackedItem = item
        context.insert(event)
        try context.save()
    }

    func fetchPending(context: ModelContext) throws -> [ReminderEvent] {
        let descriptor = FetchDescriptor<ReminderEvent>(
            predicate: #Predicate { $0.actionRaw == nil },
            sortBy: [SortDescriptor(\.scheduledAt)]
        )
        return try context.fetch(descriptor)
    }

    func fetchForItem(_ item: TrackedItem, context: ModelContext) throws -> [ReminderEvent] {
        let itemId = item.id
        let descriptor = FetchDescriptor<ReminderEvent>(
            predicate: #Predicate { $0.trackedItem?.id == itemId },
            sortBy: [SortDescriptor(\.scheduledAt, order: .reverse)]
        )
        return try context.fetch(descriptor)
    }

    func recordAction(_ action: ReminderAction, for event: ReminderEvent, context: ModelContext) throws {
        event.action = action
        event.respondedAt = .now
        try context.save()
    }
}
