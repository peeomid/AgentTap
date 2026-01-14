import AgentTapCore
import AppKit
import UserNotifications

final class NotificationCoordinator: NSObject {
    private enum Constants {
        static let category = "AgentTapPermission"
        static let focusAction = "AgentTapFocusAction"
    }

    private weak var store: AgentStore?
    private weak var settings: SettingsStore?

    func configure(store: AgentStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    @MainActor
    func activate() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        let action = UNNotificationAction(
            identifier: Constants.focusAction,
            title: "Go to session",
            options: [.foreground])
        let category = UNNotificationCategory(
            identifier: Constants.category,
            actions: [action],
            intentIdentifiers: [],
            options: [])
        center.setNotificationCategories([category])
    }

    @MainActor
    func post(events: [PermissionTransition]) {
        guard let settings, settings.notificationsEnabled else { return }
        let center = UNUserNotificationCenter.current()

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }

        for event in events {
            let instance = event.instance
            let content = UNMutableNotificationContent()
            content.title = "AgentTap - Agent needs approval"
            content.body = instance.agentLabel
            content.categoryIdentifier = Constants.category
            if let sound = sound(for: settings.notificationSound) {
                content.sound = sound
            }
            if let sessionId = instance.session?.sessionId {
                content.userInfo = ["sessionId": sessionId]
            }
            let identifier = "agenttap-permission-\(instance.sessionKey)"
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
            center.add(request) { _ in }
        }
    }

    private func sound(for selection: NotificationSound) -> UNNotificationSound? {
        switch selection {
        case .none:
            return nil
        case .default:
            return .default
        default:
            return UNNotificationSound(named: UNNotificationSoundName(rawValue: selection.rawValue))
        }
    }
}

extension NotificationCoordinator: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        if response.actionIdentifier == Constants.focusAction || response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            if let sessionId = response.notification.request.content.userInfo["sessionId"] as? String {
                let store = self.store
                Task { @MainActor in
                    if let store, let instance = store.instance(forSessionId: sessionId) {
                        try? await store.focus(instance: instance)
                    }
                }
            }
        }
        completionHandler()
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}
