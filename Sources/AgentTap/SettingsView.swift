import AgentTapCore
import SwiftUI

struct SettingsRootView: View {
    @Bindable var settings: SettingsStore
    @Bindable var store: AgentStore

    var body: some View {
        TabView {
            SettingsView(settings: settings)
                .tabItem { Text("General") }

            SetupView(store: store, settings: settings)
                .tabItem { Text("Onboarding") }
        }
        .padding(20)
        .frame(width: 520, height: 460)
    }
}

struct SettingsView: View {
    @Bindable var settings: SettingsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Preferences for alerts and refresh behavior.")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Refresh interval", selection: $settings.refreshInterval) {
                        ForEach(RefreshInterval.allCases) { interval in
                            Text(interval.displayName).tag(interval)
                        }
                    }
                    Toggle("Notify when an agent needs approval", isOn: $settings.notificationsEnabled)
                    Picker("Notification sound", selection: $settings.notificationSound) {
                        ForEach(NotificationSound.options()) { sound in
                            Text(sound.displayName).tag(sound)
                        }
                    }
                }
                .padding(8)
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    Text("agj CLI")
                        .font(.subheadline.weight(.semibold))
                    Text("Default is agj. Use a full path if agj isn’t on PATH.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Command or full path", text: $settings.agjCommand)
                        .textFieldStyle(.roundedBorder)
                }
                .padding(8)
            }

            Spacer()
        }
    }
}
