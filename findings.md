# AgentTap Recovery Findings (from binary)

> Source binary inspected: `/Applications/AgentTap.app/Contents/MacOS/AgentTap`
> Date: 2026-01-14

## Bundle identity
- Bundle ID: `com.osimify.agenttap`
- Version: `0.1.0` (build `1`)
- App type: macOS menu bar app (`LSUIElement = 1`)
- Binary: arm64 Mach-O
- Resources: `AgentTap.icns` (in app bundle)

## Where the build exists
- Full app bundle: `/Applications/AgentTap.app`
- Partial bundle (resources only): `/Users/luannguyenthanh/Development/AgentTap/AgentTap.app`

## Embedded source file names
- `AgentTap/AgentIcon.swift`
- `AgentTap/AppDelegate.swift`
- `AgentTap/EmptyStateView.swift`
- `AgentTap/MainWindowController.swift`
- `AgentTap/SettingsWindowController.swift`
- `AgentTap/SetupView.swift`
- `AgentTap/StatusItemController.swift`
- `AgentTapCore/CommandRunner.swift`
- `AgentTapCore/PathEnvironment.swift`

## Recovered modules / types
### AgentTap (UI)
- `AgentTapApp`, `AppDelegate`
- `StatusItemController`, `MainWindowController`, `SettingsWindowController`
- `MainWindowView`, `SettingsRootView`, `SettingsView`, `SetupView`
- `EmptyStateView`, `LoadingStateView`, `ErrorStateView`
- `AgentIcon`, `PermissionBadge`, `CountBadge`, `ActivityIndicator`
- `SessionSectionHeader`, `SessionHighlightStyle`
- `SettingsHeader`, `SettingsSection`
- `IconRenderer`, `LayoutMetrics`
- `SetupCheck`, `SetupCheckState`, `SetupDiagnostics`
- `NotificationCoordinator`
- `AgentType`

### AgentTapCore (logic)
- `AgentStore`
- `AGJClient`, `AGJClientError`, `AGJServing`
- `ProcessCommandRunner`, `CommandRunnerError`, `CommandResult`
- `BinaryLocator`, `EnvironmentBuilder`, `PathBuilder`
- `LoginShellPathCapturer`, `LoginShellPathCache`
- `PermissionTransition`, `PermissionTransitionDetector`
- `RefreshInterval`, `NotificationSound`, `SettingsStore`, `HealthStatus`

## Data models + fields (decoded from symbols)
- `AgentProcess`: `pid`, `name`, `cmdline`, `ancestry`
- `AgentSession`: `sessionId`, `tabId`, `windowId`, `pid`, `title`, `path`
- `AgentInstance`:
  - stored: `id`, `process`, `session`, `permissionPrompt`, `permissionReason`, `permissionOutput`
  - computed: `displayName`, `displayPath`, `shortPath`, `agentTypeName`, `agentLabel`, `needsAttention`, `permissionStatusText`, `sessionKey`

## AGJ integration (inferred from symbols + strings)
- `AGJClient.listInstances()`
- `AGJClient.focus(instance:)`
- `AGJClient.captureOutput(instance:lines:)`
- Process runner: `ProcessCommandRunner.run(_:arguments:)`
- Environment / path handling:
  - `AGJ_CLI_PATH`, `__AGENTTAP_PATH__`
  - login-shell PATH capture
- CLI args observed: `--id`, `--session`
- JSON keys observed: `session_id`, `tab_id`, `window_id`, `permission_prompt`, `permission_reason`, `permission_output`, `cmdline`, `ancestry`, `name`, `path`, `title`, `pid`

## Settings keys (UserDefaults)
- `AgentTap.notificationsEnabled`
- `AgentTap.refreshInterval`
- `AgentTap.notificationSound`
- `AgentTap.agjCommand`
- `AgentTap.didShowSetupPrompt`

## Refresh interval options (strings)
- Every 3 seconds
- Every 1 minute
- Every 2 minutes
- Every 5 minutes
- Every 15 minutes

## UI strings (sample)
- “Start a Claude Code, Cursor, or other AI coding session to see it here.”
- “Permission required” / “Permission prompt detected.”
- “A quick setup is needed so AgentTap can find agj and talk to iTerm2.”
- “Open AgentTap Window”, “Settings”, “Refresh Now”, “Sessions”, “Quit AgentTap”
- “agj not found on PATH. Install with: pipx install agj”
- “Looks good. If focus/capture fails, enable iTerm2 Python API.”

## Agent types seen in strings
- `claude`, `cursor`, `aider`

## Frameworks linked
- AppKit, SwiftUI, Foundation, CoreGraphics, CoreFoundation, UserNotifications, Observation, Swift runtime

## Limits
- Full Swift source cannot be recovered from the binary; only symbols, strings, and inferred structure are available.

## Recovered icon assets (saved locally)
- `AgentTap/icons/AgentTap.icns` (from `/Applications/AgentTap.app/Contents/Resources`)
- `AgentTap/icons/Icon.icns` (from old bundle)
- `AgentTap/icons/Icon.iconset/` (from old bundle)
- `AgentTap/icons/icon-*.png` (from `/Users/luannguyenthanh/Development/AgentTap/icon-options`)
