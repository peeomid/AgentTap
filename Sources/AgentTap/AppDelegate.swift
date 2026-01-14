import AgentTapCore
import AppKit
import SwiftUI
import UserNotifications

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: AgentStore?
    private var settings: SettingsStore?
    private var statusController: StatusItemController?
    private let notificationCoordinator = NotificationCoordinator()

    func configure(store: AgentStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        guard let store, let settings else { return }
        statusController = StatusItemController(store: store, settings: settings)
        if AppEnvironment.isRunningFromAppBundle {
            notificationCoordinator.configure(store: store, settings: settings)
            notificationCoordinator.activate()
            store.notificationHandler = { [weak self] events in
                Task { @MainActor in
                    self?.notificationCoordinator.post(events: events)
                }
            }
        }
        store.start()

        LoginShellPathCache.shared.captureOnce()
    }

    func applicationWillTerminate(_ notification: Notification) {
        store?.stop()
    }

    @objc func openMainWindow() {
        guard let store, let settings else { return }
        MainWindowController.shared.show(store: store, settings: settings)
    }

    @objc func openSettings() {
        guard let store, let settings else { return }
        SettingsWindowController.shared.show(settings: settings, store: store)
    }
}
