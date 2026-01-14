# AgentTap Repo Guide

This file is a quick navigation map for the AgentTap project.

## Top-level layout
- `Package.swift`: SwiftPM manifest for the app + core module.
- `Sources/AgentTap`: macOS menu bar app (UI + AppKit glue).
- `Sources/AgentTapCore`: core logic + agj integration.
- `Scripts/`: packaging/signing helpers.
- `Tests/AgentTapCoreTests`: minimal unit tests for core logic.
- `version.env`: app version/build used by scripts.
- `icons/`: collected icon assets and options.
- `findings.md`: reverse‑engineered details from old binary.
- `requirements.md`: product requirements.

## Key modules
### AgentTap (UI)
- `AgentTapApp.swift`: App entry point + Settings scene.
- `AppDelegate.swift`: status item + notifications wiring.
- `StatusItemController.swift`: menu bar icon + menu content.
- `MainWindowController.swift`: main window wrapper.
- `MainWindowView.swift`: session list + details UI.
- `SettingsWindowController.swift`: settings window for menu action.
- `SettingsView.swift`: Settings tabs (General + Onboarding).
- `SetupView.swift`: onboarding/diagnostics checks.
- `NotificationCoordinator.swift`: notification handling.
- `AgentType.swift`: agent type detection + icons.
- `AgentIcon.swift`: small SwiftUI icon view.
- `Components.swift`: badges + small UI pieces.
- `EmptyStateView.swift`: empty/error states.
- `IconRenderer.swift`: status bar icon rendering.
- `Resources/AgentTap.icns`: app icon.

### AgentTapCore (logic)
- `AgentModels.swift`: `AgentProcess`, `AgentSession`, `AgentInstance`, `HealthStatus`.
- `AGJClient.swift`: runs `agj` (`list`, `focus`, `capture`) + JSON decode.
- `CommandRunner.swift`: process runner + stdout/stderr capture.
- `PathEnvironment.swift`: PATH resolution + login-shell PATH capture.
- `SettingsStore.swift`: persisted settings + defaults.
- `PermissionTransitionDetector.swift`: detects new permission prompts.
- `AgentStore.swift`: refresh loop + notification events + output cache.

## Running
- Build: `swift build`
- Run without bundle: `swift run AgentTap`
- Package app bundle: `Scripts/package_app.sh`
- Open packaged app: `open -n AgentTap.app`

## Scripts
- `Scripts/package_app.sh`: builds SwiftPM output into `AgentTap.app` with Info.plist and icon.
- `Scripts/sign-and-notarize.sh`: codesign helper (notarization is manual).

## Settings (UserDefaults keys)
- `AgentTap.refreshInterval`
- `AgentTap.notificationsEnabled`
- `AgentTap.notificationSound`
- `AgentTap.agjCommand`

## agj integration
- CLI spec lives in `/Users/luannguyenthanh/Development/Osimify/agj/CLI_SPEC.md`.
- AgentTap uses:
  - `agj list --json --with-path`
  - `agj focus --session <id>`
  - `agj capture --session <id> --lines <n>`

## Notes / gotchas
- Notifications require a packaged `.app` bundle. `swift run` disables notifications to avoid crashes.
- Menu is AppKit-based; Settings window is a custom `NSWindow` to ensure it opens from menu.

