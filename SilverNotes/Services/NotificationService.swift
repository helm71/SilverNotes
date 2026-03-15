import Foundation
import UserNotifications
import SwiftData

final class NotificationService: NSObject {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    enum Category: String {
        case actionReminder = "ACTION_REMINDER"
    }

    enum ActionIdentifier: String {
        case stop = "STOP"
        case snooze = "SNOOZE"
        case complete = "COMPLETE"
    }

    override private init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    private func registerCategories() {
        let snoozeDuration = AppSettings.shared.snoozeDuration
        let stop = UNNotificationAction(identifier: ActionIdentifier.stop.rawValue, title: "Stop", options: [.destructive])
        let snooze = UNNotificationAction(identifier: ActionIdentifier.snooze.rawValue, title: "Snooze (\(snoozeDuration) min)", options: [])
        let complete = UNNotificationAction(identifier: ActionIdentifier.complete.rawValue, title: "✓ Afgerond", options: [.authenticationRequired])

        let category = UNNotificationCategory(
            identifier: Category.actionReminder.rawValue,
            actions: [stop, snooze, complete],
            intentIdentifiers: [],
            options: []
        )
        center.setNotificationCategories([category])
    }

    func scheduleNotification(for action: Action) {
        guard let dueDate = action.dueDate else { return }
        let leadTime = TimeInterval(AppSettings.shared.notificationLeadTime * 60)
        let triggerDate = dueDate.addingTimeInterval(-leadTime)
        guard triggerDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Actie herinnering"
        content.body = action.title
        if let detail = action.detail, !detail.isEmpty {
            content.subtitle = detail
        }
        content.sound = .default
        content.categoryIdentifier = Category.actionReminder.rawValue
        content.userInfo = ["actionId": action.id.uuidString, "dueDate": dueDate.timeIntervalSince1970]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: triggerDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: action.notificationIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("[Notification] Schedule error: \(error)") }
        }
    }

    func updateBadge(count: Int) {
        UNUserNotificationCenter.current().setBadgeCount(count) { error in
            if let error { print("[Badge] Error: \(error)") }
        }
    }

    func cancelNotification(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    func rescheduleSnooze(for identifier: String, actionTitle: String, actionId: String) {
        let snoozeMinutes = AppSettings.shared.snoozeDuration
        let snoozeDate = Date().addingTimeInterval(TimeInterval(snoozeMinutes * 60))

        let content = UNMutableNotificationContent()
        content.title = "Actie herinnering (gesnoozed)"
        content.body = actionTitle
        content.sound = .default
        content.categoryIdentifier = Category.actionReminder.rawValue
        content.userInfo = ["actionId": actionId]

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: snoozeDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let snoozeIdentifier = "\(identifier)-snooze-\(UUID().uuidString)"
        let request = UNNotificationRequest(identifier: snoozeIdentifier, content: content, trigger: trigger)

        center.add(request) { error in
            if let error { print("[Notification] Snooze error: \(error)") }
        }
    }
}

extension NotificationService: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let userInfo = response.notification.request.content.userInfo
        guard let actionIdString = userInfo["actionId"] as? String,
              let actionId = UUID(uuidString: actionIdString) else { return }

        let actionIdentifier = ActionIdentifier(rawValue: response.actionIdentifier)

        await MainActor.run {
            NotificationCenter.default.post(
                name: .notificationActionReceived,
                object: nil,
                userInfo: [
                    "actionId": actionId,
                    "response": response.actionIdentifier,
                    "notificationId": response.notification.request.identifier
                ]
            )
        }

        if actionIdentifier == .snooze {
            let title = response.notification.request.content.body
            let identifier = response.notification.request.identifier
            Task { @MainActor in
                self.rescheduleSnooze(for: identifier, actionTitle: title, actionId: actionIdString)
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }
}

extension Notification.Name {
    static let notificationActionReceived = Notification.Name("notificationActionReceived")
}
