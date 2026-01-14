import AgentTapCore
import AppKit
import SwiftUI

struct MainWindowView: View {
    @Bindable var store: AgentStore
    @Bindable var settings: SettingsStore
    @State private var selection: AgentInstance.ID?

    var body: some View {
        NavigationSplitView {
            List(selection: $selection) {
                if store.instances.isEmpty {
                    NoSessionsEmptyState()
                } else {
                    ForEach(groupedInstances) { group in
                        Section(group.title) {
                            ForEach(group.instances) { instance in
                                InstanceRow(instance: instance)
                                    .tag(instance.id)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Sessions")
        } detail: {
            if let selection, let instance = store.instance(forId: selection) {
                InstanceDetailView(store: store, instance: instance)
            } else if store.isRefreshing && store.instances.isEmpty {
                LoadingStateView()
            } else if let message = store.health.message {
                ErrorStateView(message: message)
            } else {
                NoSelectionEmptyState()
            }
        }
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button("Refresh") {
                    Task { await store.refresh() }
                }
            }
            ToolbarItem(placement: .automatic) {
                Button("Settings") {
                    NSApp.activate(ignoringOtherApps: true)
                    _ = NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
            }
        }
    }

    private var groupedInstances: [SessionGroup] {
        SessionGroup.group(instances: store.instances)
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

private struct InstanceRow: View {
    let instance: AgentInstance

    var body: some View {
        let type = AgentType(instance: instance)
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                AgentIcon(agentType: type, size: 16, showBackground: true)
                Text(instance.agentTypeName)
                    .font(.headline)
                Spacer()
                if instance.needsAttention {
                    PermissionBadge()
                }
            }
            if let path = instance.shortPath {
                Text(path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct InstanceDetailView: View {
    @Bindable var store: AgentStore
    let instance: AgentInstance
    @State private var output: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                let type = AgentType(instance: instance)
                AgentIcon(agentType: type, size: 24, showBackground: true)
                VStack(alignment: .leading) {
                    Text(instance.agentLabel)
                        .font(.title2.weight(.semibold))
                    Text(instance.shortPath ?? "No Path")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button("Focus Window") {
                    Task { try? await store.focus(instance: instance) }
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Session Details")
                    .font(.headline)
                DetailRow(label: "PID", value: String(instance.process.pid))
                if let title = instance.session?.title {
                    DetailRow(label: "Tab", value: title)
                }
                if let sessionId = instance.session?.sessionId {
                    DetailRow(label: "Session", value: sessionId)
                }
                DetailRow(label: "Status", value: instance.permissionStatusText)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Output")
                        .font(.headline)
                    Spacer()
                    Button("Refresh Now") {
                        Task { await store.fetchOutput(for: instance) }
                    }
                }
                TextEditor(text: Binding(
                    get: { store.output(for: instance) ?? output },
                    set: { output = $0 }
                ))
                .font(.system(.caption, design: .monospaced))
                .frame(minHeight: 200)
            }
            Spacer()
        }
        .padding(20)
        .onAppear {
            if store.output(for: instance) == nil {
                Task { await store.fetchOutput(for: instance) }
            }
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top) {
            Text(label)
                .frame(width: 90, alignment: .leading)
                .foregroundStyle(.secondary)
            Text(value)
                .textSelection(.enabled)
            Spacer()
        }
        .font(.callout)
    }
}
