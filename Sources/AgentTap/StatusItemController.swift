import AgentTapCore
import AppKit

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu: NSMenu
    private let store: AgentStore
    private let settings: SettingsStore
    private var storeObserver: AgentStore.ObserverToken?
    private var settingsObserver: SettingsStore.ObserverToken?
    private var animationTimer: Timer?
    private var animationPhase: Double = 0
    private let animationDuration: Double = 1.6  // Match SVG animation duration

    init(store: AgentStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
        self.menu.autoenablesItems = false
        super.init()

        menu.delegate = self
        statusItem.menu = menu
        updateStatusIcon()

        storeObserver = store.addObserver { [weak self] in
            self?.updateStatusIcon()
        }
        settingsObserver = settings.addObserver { [weak self] in
            self?.updateStatusIcon()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        Task { await store.refresh() }
        rebuildMenu()
    }

    private func rebuildMenu() {
        menu.removeAllItems()

        menu.addItem(makeHeaderItem())
        menu.addItem(NSMenuItem.separator())

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshNow), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let openWindowItem = NSMenuItem(title: "Open AgentTap Window…", action: #selector(openWindow), keyEquivalent: "o")
        openWindowItem.target = self
        menu.addItem(openWindowItem)

        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let sessionsHeader = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        sessionsHeader.attributedTitle = NSAttributedString(
            string: "Sessions",
            attributes: [
                .font: NSFont.systemFont(ofSize: NSFont.systemFontSize, weight: .bold),
            ])
        // Keep enabled so text isn't auto-dimmed, but no action = not clickable
        menu.addItem(sessionsHeader)

        let groups = SessionGroup.group(instances: store.instances)
        if groups.isEmpty {
            let empty = NSMenuItem(title: "No active agents", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for group in groups {
                let header = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.attributedTitle = attributedGroupTitle(for: group)
                header.image = groupIcon(for: group)
                menu.addItem(header)

                for instance in group.instances {
                    let item = NSMenuItem(title: "", action: #selector(focusInstance(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = instance
                    item.attributedTitle = attributedTitle(for: instance)
                    item.image = rowIcon(for: instance)
                    item.indentationLevel = 1
                    menu.addItem(item)
                }

                // Subtle centered dot separator between groups
                let spacer = NSMenuItem(title: "", action: nil, keyEquivalent: "")
                let paragraphStyle = NSMutableParagraphStyle()
                paragraphStyle.alignment = .center
                spacer.attributedTitle = NSAttributedString(
                    string: "· · ·",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 10, weight: .bold),
                        .foregroundColor: NSColor.tertiaryLabelColor,
                        .paragraphStyle: paragraphStyle,
                    ])
                menu.addItem(spacer)
            }
        }

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AgentTap", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
    }

    private func makeHeaderItem() -> NSMenuItem {
        let item = NSMenuItem(title: "AgentTap", action: nil, keyEquivalent: "")
        item.isEnabled = false
        let updated = store.lastUpdated.map { DateFormatter.menuTime.string(from: $0) } ?? "--:--:--"
        let title = NSMutableAttributedString(
            string: "AgentTap\n",
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        let subtitle = NSAttributedString(
            string: "Updated \(updated)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ])
        title.append(subtitle)
        item.attributedTitle = title
        item.image = IconRenderer.makeNormalIcon()
        return item
    }

    private func attributedGroupTitle(for group: SessionGroup) -> NSAttributedString {
        let title = NSMutableAttributedString()

        // Add sparkle if any instance needs attention
        let needsAttention = group.instances.contains { $0.needsAttention }
        if needsAttention {
            title.append(NSAttributedString(
                string: "✱ ",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        }

        // Group title
        title.append(NSAttributedString(
            string: group.title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12, weight: .medium),
                .foregroundColor: NSColor.labelColor,
            ]))

        // Add dominant agent type suffix if available
        if let dominantType = dominantAgentType(in: group) {
            title.append(NSAttributedString(
                string: " (\(dominantType.displayName.lowercased()))",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        }

        return title
    }

    private func dominantAgentType(in group: SessionGroup) -> AgentType? {
        let types = group.instances.map { AgentType(instance: $0) }
        let counts = Dictionary(grouping: types) { $0 }.mapValues { $0.count }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func groupIcon(for group: SessionGroup) -> NSImage? {
        guard let symbol = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil) else {
            return nil
        }

        // Use muted purple for folder icons (matching screenshot)
        let mutedPurple = NSColor(red: 0.55, green: 0.45, blue: 0.7, alpha: 0.8)
        let config = NSImage.SymbolConfiguration(paletteColors: [mutedPurple])
        return symbol.withSymbolConfiguration(config)
    }

    private func attributedTitle(for instance: AgentInstance) -> NSAttributedString {
        let title = NSMutableAttributedString()

        // Set up paragraph style with right-aligned tab stop for badge
        let paragraphStyle = NSMutableParagraphStyle()
        let rightTabStop = NSTextTab(textAlignment: .right, location: 200)
        paragraphStyle.tabStops = [rightTabStop]

        // Agent name
        let name = NSAttributedString(
            string: instance.agentTypeName,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
                .paragraphStyle: paragraphStyle,
            ])
        title.append(name)

        // Asking badge (right-aligned using tab stop)
        if instance.needsAttention {
            let badge = NSAttributedString(
                string: "\t● Asking",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.systemOrange,
                    .paragraphStyle: paragraphStyle,
                ])
            title.append(badge)
        }

        // Path on second line
        if let path = instance.shortPath {
            title.append(NSAttributedString(string: "\n"))
            title.append(NSAttributedString(
                string: path,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11),
                    .foregroundColor: NSColor.secondaryLabelColor,
                ]))
        }

        return title
    }

    private func rowIcon(for instance: AgentInstance) -> NSImage? {
        let type = AgentType(instance: instance)
        guard let symbol = NSImage(systemSymbolName: type.iconName, accessibilityDescription: nil) else {
            return nil
        }

        // Muted colors for each agent type
        let color: NSColor = switch type {
        case .codex:
            NSColor(red: 0.45, green: 0.65, blue: 0.75, alpha: 0.85)  // Muted teal
        case .claude:
            NSColor(red: 0.75, green: 0.55, blue: 0.45, alpha: 0.85)  // Muted orange
        case .cursor:
            NSColor(red: 0.65, green: 0.50, blue: 0.70, alpha: 0.85)  // Muted purple
        case .aider:
            NSColor(red: 0.50, green: 0.65, blue: 0.50, alpha: 0.85)  // Muted green
        case .continue:
            NSColor(red: 0.45, green: 0.60, blue: 0.60, alpha: 0.85)  // Muted teal
        case .node:
            NSColor(red: 0.55, green: 0.50, blue: 0.70, alpha: 0.85)  // Muted indigo
        case .unknown:
            NSColor(red: 0.55, green: 0.55, blue: 0.55, alpha: 0.85)  // Muted gray
        }

        let config = NSImage.SymbolConfiguration(paletteColors: [color])
        return symbol.withSymbolConfiguration(config)
    }

    private func updateStatusIcon() {
        let needsAttention = store.instances.contains { $0.needsAttention }

        if needsAttention {
            startAnimationIfNeeded()
        } else {
            stopAnimation()
            statusItem.button?.image = IconRenderer.makeNormalIcon()
        }

        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "AgentTap"
    }

    private func startAnimationIfNeeded() {
        guard animationTimer == nil else { return }

        // Update icon immediately
        statusItem.button?.image = IconRenderer.makeAlertIcon(phase: animationPhase)

        // Start animation timer (60fps for smooth animation)
        let interval: TimeInterval = 1.0 / 60.0
        animationTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimationFrame()
            }
        }
    }

    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        animationPhase = 0
    }

    private func updateAnimationFrame() {
        // Increment phase based on animation duration
        animationPhase += (1.0 / 60.0) / animationDuration
        if animationPhase >= 1.0 {
            animationPhase = 0
        }

        statusItem.button?.image = IconRenderer.makeAlertIcon(phase: animationPhase)
    }

    @objc private func focusInstance(_ sender: NSMenuItem) {
        guard let instance = sender.representedObject as? AgentInstance else { return }
        Task { try? await store.focus(instance: instance) }
    }

    @objc private func refreshNow() {
        Task { await store.refresh() }
    }

    @objc private func openWindow() {
        (NSApp.delegate as? AppDelegate)?.openMainWindow()
    }

    @objc private func openSettings() {
        (NSApp.delegate as? AppDelegate)?.openSettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

private struct SessionGroup: Identifiable {
    let id: String
    let title: String
    let instances: [AgentInstance]

    static func group(instances: [AgentInstance]) -> [SessionGroup] {
        let grouped = Dictionary(grouping: instances) { instance in
            instance.session?.tabId ?? "no-tab"
        }
        return grouped
            .map { key, value in
                let title = value.first?.session?.title ?? "No Tab"
                return SessionGroup(id: key, title: title, instances: value)
            }
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }
}

private extension DateFormatter {
    static let menuTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter
    }()
}
