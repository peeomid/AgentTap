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

    init(store: AgentStore, settings: SettingsStore) {
        self.store = store
        self.settings = settings
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.menu = NSMenu()
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

        let settingsItem = NSMenuItem(title: "Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let sessionsHeader = NSMenuItem(title: "Sessions", action: nil, keyEquivalent: "")
        sessionsHeader.isEnabled = false
        menu.addItem(sessionsHeader)

        let groups = SessionGroup.group(instances: store.instances)
        if groups.isEmpty {
            let empty = NSMenuItem(title: "No active agents", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for group in groups {
                let header = NSMenuItem(title: group.title, action: nil, keyEquivalent: "")
                header.isEnabled = false
                header.image = NSImage(systemSymbolName: "folder.fill", accessibilityDescription: nil)
                header.image?.isTemplate = true
                menu.addItem(header)

                for instance in group.instances {
                    let item = NSMenuItem(title: "", action: #selector(focusInstance(_:)), keyEquivalent: "")
                    item.target = self
                    item.representedObject = instance
                    item.attributedTitle = attributedTitle(for: instance)
                    item.image = rowIcon(for: instance)
                    menu.addItem(item)
                }

                menu.addItem(.separator())
            }
        }

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
                .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
                .foregroundColor: NSColor.secondaryLabelColor,
            ])
        let subtitle = NSAttributedString(
            string: "Updated \(updated)",
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.tertiaryLabelColor,
            ])
        title.append(subtitle)
        item.attributedTitle = title
        return item
    }

    private func attributedTitle(for instance: AgentInstance) -> NSAttributedString {
        let title = NSMutableAttributedString()
        let name = NSAttributedString(
            string: instance.agentTypeName,
            attributes: [
                .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ])
        title.append(name)

        if instance.needsAttention {
            let badge = NSAttributedString(
                string: "  ● Asking",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 11, weight: .semibold),
                    .foregroundColor: NSColor.systemOrange,
                ])
            title.append(badge)
        }

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
        let symbol = NSImage(systemSymbolName: type.iconName, accessibilityDescription: nil)
        symbol?.isTemplate = true
        return symbol
    }

    private func updateStatusIcon() {
        let needsAttention = store.instances.contains { $0.needsAttention }
        let image = needsAttention ? IconRenderer.makeAlertIcon() : IconRenderer.makeNormalIcon()
        statusItem.button?.image = image
        statusItem.button?.imagePosition = .imageOnly
        statusItem.button?.toolTip = "AgentTap"
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
