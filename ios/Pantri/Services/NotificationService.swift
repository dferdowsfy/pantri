import Foundation
import UserNotifications
import SwiftData

// MARK: - Protocol

protocol NotificationServiceProtocol {
    func requestPermission() async -> Bool
    func scheduleReminders(for predictions: [ItemPrediction]) async
    func cancelReminder(for itemId: UUID)
    func rescheduleAll(context: ModelContext) async throws
}

// MARK: - Implementation

final class NotificationService: NotificationServiceProtocol {
    static let categoryIdentifier = "PANTRI_ITEM_REMINDER"
    static let boughtActionIdentifier = "BOUGHT_ACTION"
    static let remindLaterActionIdentifier = "REMIND_LATER_ACTION"

    private let center = UNUserNotificationCenter.current()
    private let predictionService: PredictionServiceProtocol
    private let copyGenerator: NotificationCopyGenerating

    init(
        predictionService: PredictionServiceProtocol = PredictionService(),
        copyGenerator: NotificationCopyGenerating = NotificationCopyGenerator()
    ) {
        self.predictionService = predictionService
        self.copyGenerator = copyGenerator
    }

    /// Register notification categories with interactive actions.
    func registerCategories() {
        let boughtAction = UNNotificationAction(
            identifier: Self.boughtActionIdentifier,
            title: "Bought",
            options: [.foreground]
        )
        let remindLaterAction = UNNotificationAction(
            identifier: Self.remindLaterActionIdentifier,
            title: "Remind Later",
            options: []
        )

        let category = UNNotificationCategory(
            identifier: Self.categoryIdentifier,
            actions: [boughtAction, remindLaterAction],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func requestPermission() async -> Bool {
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .badge, .sound])
            if granted { registerCategories() }
            return granted
        } catch {
            return false
        }
    }

    func scheduleReminders(for predictions: [ItemPrediction]) async {
        // Only schedule for needSoon or buyNow items
        let actionable = predictions.filter { $0.status == .needSoon || $0.status == .buyNow }

        // Get currently pending notifications to avoid duplicates
        let pendingRequests = await center.pendingNotificationRequests()
        let pendingIds = Set(pendingRequests.map(\.identifier))

        for prediction in actionable {
            let notificationId = notificationIdentifier(for: prediction.itemId)

            // Using the item ID as the notification identifier auto-replaces any existing
            // notification for the same item (dedup).
            let content = UNMutableNotificationContent()
            content.title = "Pantri"
            content.body = copyGenerator.generateBody(for: prediction)
            content.sound = .default
            content.categoryIdentifier = Self.categoryIdentifier
            content.userInfo = ["itemId": prediction.itemId.uuidString]

            // Schedule for a reasonable time — next morning at 9 AM if not already due
            let trigger: UNNotificationTrigger
            if prediction.status == .buyNow {
                // Deliver soon (within a minute)
                trigger = UNTimeIntervalNotificationTrigger(timeInterval: 60, repeats: false)
            } else {
                // Deliver tomorrow morning at 9 AM
                var dateComponents = DateComponents()
                dateComponents.hour = 9
                dateComponents.minute = 0
                trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: false)
            }

            let request = UNNotificationRequest(
                identifier: notificationId,
                content: content,
                trigger: trigger
            )

            do {
                try await center.add(request)
            } catch {
                // Notification scheduling failed — not critical, continue
            }
        }
    }

    func cancelReminder(for itemId: UUID) {
        center.removePendingNotificationRequests(
            withIdentifiers: [notificationIdentifier(for: itemId)]
        )
    }

    func rescheduleAll(context: ModelContext) async throws {
        // Cancel all existing Pantri notifications
        center.removeAllPendingNotificationRequests()

        // Recompute predictions and schedule fresh
        let predictions = try predictionService.predictAll(context: context)
        await scheduleReminders(for: predictions)
    }

    // MARK: - Private

    private func notificationIdentifier(for itemId: UUID) -> String {
        "pantri_item_\(itemId.uuidString)"
    }
}
