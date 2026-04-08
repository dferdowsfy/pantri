import Foundation
import SwiftData

@Model
final class ReminderEvent {
    @Attribute(.unique) var id: UUID
    var scheduledAt: Date
    var actionRaw: String?
    var respondedAt: Date?
    var snoozedUntil: Date?
    var createdAt: Date

    @Relationship(inverse: \TrackedItem.reminderEvents)
    var trackedItem: TrackedItem?

    var action: ReminderAction? {
        get {
            guard let actionRaw else { return nil }
            return ReminderAction(rawValue: actionRaw)
        }
        set { actionRaw = newValue?.rawValue }
    }

    init(
        id: UUID = UUID(),
        scheduledAt: Date,
        action: ReminderAction? = nil,
        respondedAt: Date? = nil,
        snoozedUntil: Date? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.scheduledAt = scheduledAt
        self.actionRaw = action?.rawValue
        self.respondedAt = respondedAt
        self.snoozedUntil = snoozedUntil
        self.createdAt = createdAt
    }
}
