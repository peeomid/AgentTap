import AgentTapCore
import AppKit
import SwiftUI
import UserNotifications

struct SetupView: View {
    @Bindable var store: AgentStore
    @Bindable var settings: SettingsStore
    @State private var diagnostics: SetupDiagnostics.Result = .empty
    @State private var isChecking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Make sure AgentTap can find agj and talk to iTerm2.")
                .font(.headline)

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    SetupStatusRow(title: "agj", check: diagnostics.agjStatus)
                    SetupStatusRow(title: "iTerm running", check: diagnostics.itermStatus)
                    SetupStatusRow(title: "iTerm Python API", check: diagnostics.itermPythonStatus)
                    SetupStatusRow(title: "Notifications", check: diagnostics.notificationStatus)
                }
                .padding(8)
            }

            HStack(spacing: 12) {
                Button(isChecking ? "Checking…" : "Run checks") {
                    Task { await runChecks() }
                }
                .disabled(isChecking)

                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }

            if !diagnostics.detailMessage.isEmpty {
                Text(diagnostics.detailMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .onAppear {
            Task { await runChecks() }
        }
    }

    private func runChecks() async {
        isChecking = true
        diagnostics = await SetupDiagnostics.checkAll(store: store, settings: settings)
        isChecking = false
    }
}

struct SetupStatusRow: View {
    let title: String
    let check: SetupCheck

    var body: some View {
        HStack {
            Image(systemName: check.state.symbolName)
                .foregroundStyle(Color(nsColor: check.state.tintColor))
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

struct SetupCheck: Equatable {
    let state: SetupCheckState
    let detail: String
}

enum SetupCheckState: Equatable {
    case ok
    case warning
    case error
    case pending

    var symbolName: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .pending: return "clock.fill"
        }
    }

    var tintColor: NSColor {
        switch self {
        case .ok: return .systemGreen
        case .warning: return .systemOrange
        case .error: return .systemRed
        case .pending: return .secondaryLabelColor
        }
    }
}

@MainActor
enum SetupDiagnostics {
    struct Result {
        var agjStatus: SetupCheck
        var itermStatus: SetupCheck
        var itermPythonStatus: SetupCheck
        var notificationStatus: SetupCheck
        var detailMessage: String

        static let empty = Result(
            agjStatus: SetupCheck(state: .pending, detail: "agj check: not run yet."),
            itermStatus: SetupCheck(state: .pending, detail: "No session checks yet. Click Run checks."),
            itermPythonStatus: SetupCheck(state: .pending, detail: "No session checks yet. Click Run checks."),
            notificationStatus: SetupCheck(state: .pending, detail: "No prompt appeared. Try again, or open System Settings to enable notifications."),
            detailMessage: ""
        )
    }

    static func checkAll(store: AgentStore, settings: SettingsStore) async -> Result {
        let agj = await agjStatus(settings: settings)
        let iterm = iTermRunningStatus()
        let python = await iTermPythonStatus(store: store, agjStatus: agj)
        let notification = await notificationStatus()
        var detailMessage = ""
        if case .error(let message) = store.health {
            detailMessage = message
        }
        return Result(
            agjStatus: agj,
            itermStatus: iterm,
            itermPythonStatus: python,
            notificationStatus: notification,
            detailMessage: detailMessage)
    }

    static func agjStatus(settings: SettingsStore) async -> SetupCheck {
        let runner = ProcessCommandRunner(agjCommandOverride: {
            let override = settings.agjCommand.trimmingCharacters(in: .whitespacesAndNewlines)
            return override.isEmpty ? nil : override
        })
        do {
            let result = try await runner.run("list", arguments: ["--json", "--max", "1"])
            if result.exitCode == 3 {
                return SetupCheck(state: .error, detail: "iTerm2 Python API unavailable.")
            }
            if result.exitCode != 0 && result.exitCode != 1 {
                let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
                return SetupCheck(state: .error, detail: detail.isEmpty ? "agj check failed." : detail)
            }
            return SetupCheck(state: .ok, detail: "Found agj on PATH.")
        } catch let error as CommandRunnerError {
            return SetupCheck(state: .error, detail: error.localizedDescription)
        } catch {
            return SetupCheck(state: .error, detail: error.localizedDescription)
        }
    }

    static func iTermRunningStatus() -> SetupCheck {
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.googlecode.iterm2").isEmpty == false
        if running {
            return SetupCheck(state: .ok, detail: "iTerm2 is running.")
        }
        return SetupCheck(state: .warning, detail: "Open iTerm2 and keep it running while AgentTap is active.")
    }

    static func iTermPythonStatus(store: AgentStore, agjStatus: SetupCheck) async -> SetupCheck {
        if agjStatus.state == .error {
            return SetupCheck(state: .warning, detail: "Install agj first to validate the Python API.")
        }
        await store.refresh()
        switch store.health {
        case .itermUnavailable:
            return SetupCheck(state: .error, detail: "iTerm2 Python API unavailable.")
        case .healthy:
            return SetupCheck(state: .ok, detail: "Looks good. If focus/capture fails, enable iTerm2 Python API.")
        case .agjMissing(let detail):
            return SetupCheck(state: .warning, detail: detail)
        case .error(let detail):
            return SetupCheck(state: .warning, detail: detail)
        }
    }

    static func notificationStatus() async -> SetupCheck {
        guard AppEnvironment.isRunningFromAppBundle else {
            return SetupCheck(state: .warning, detail: "Notifications require a packaged .app. Run Scripts/package_app.sh.")
        }
        let center = UNUserNotificationCenter.current()
        return await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                let status: SetupCheck
                switch settings.authorizationStatus {
                case .authorized, .provisional:
                    status = SetupCheck(state: .ok, detail: "Notifications are enabled.")
                case .denied:
                    status = SetupCheck(state: .error, detail: "Notifications are denied for AgentTap. Open System Settings to enable them.")
                case .notDetermined:
                    status = SetupCheck(state: .warning, detail: "No prompt appeared. Try again, or open System Settings to enable notifications.")
                @unknown default:
                    status = SetupCheck(state: .warning, detail: "Unknown notification status.")
                }
                continuation.resume(returning: status)
            }
        }
    }
}
