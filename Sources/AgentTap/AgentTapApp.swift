import AgentTapCore
import AppKit
import Observation
import SwiftUI

@main
struct AgentTapApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var settings: SettingsStore
    @State private var store: AgentStore

    init() {
        let settings = SettingsStore()
        let runner = ProcessCommandRunner(agjCommandOverride: {
            let override = settings.agjCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            return override.isEmpty ? nil : override
        })
        let client = AGJClient(runner: runner)
        let store = AgentStore(client: client, settings: settings)
        _settings = State(wrappedValue: settings)
        _store = State(wrappedValue: store)
        appDelegate.configure(store: store, settings: settings)
    }

    var body: some Scene {
        WindowGroup("AgentTapLifecycleKeepalive") {
            HiddenWindowView()
        }
        .defaultSize(width: 20, height: 20)
        .windowStyle(.hiddenTitleBar)

        Settings {
            SettingsRootView(settings: settings, store: store)
        }
        .defaultSize(width: 560, height: 520)
        .windowResizability(.contentSize)
    }
}

struct HiddenWindowView: View {
    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
    }
}
