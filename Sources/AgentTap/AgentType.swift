import AgentTapCore
import AppKit
import SwiftUI

enum AgentType: String, CaseIterable {
    case codex
    case claude
    case cursor
    case aider
    case `continue`
    case node
    case unknown

    init(processName: String) {
        let lower = processName.lowercased()
        if lower.contains("codex") { self = .codex; return }
        if lower.contains("claude") { self = .claude; return }
        if lower.contains("cursor") { self = .cursor; return }
        if lower.contains("aider") { self = .aider; return }
        if lower.contains("continue") { self = .continue; return }
        if lower.contains("node") { self = .node; return }
        self = .unknown
    }

    init(instance: AgentInstance) {
        let combined = instance.process.name + " " + instance.process.cmdline.joined(separator: " ")
        self.init(processName: combined)
    }

    var displayName: String {
        switch self {
        case .codex: return "Codex"
        case .claude: return "Claude"
        case .cursor: return "Cursor"
        case .aider: return "Aider"
        case .continue: return "Continue"
        case .node: return "Node"
        case .unknown: return "Agent"
        }
    }

    var iconName: String {
        switch self {
        case .codex: return "terminal.fill"
        case .claude: return "sparkle"
        case .cursor: return "cursorarrow.rays"
        case .aider: return "bolt.fill"
        case .continue: return "play.circle.fill"
        case .node: return "cube.fill"
        case .unknown: return "circle.dotted"
        }
    }
}

enum SessionHighlightStyle {
    static func agentBrand(for type: AgentType) -> Color {
        switch type {
        case .codex: return .blue
        case .claude: return .orange
        case .cursor: return .purple
        case .aider: return .green
        case .continue: return .teal
        case .node: return .indigo
        case .unknown: return .gray
        }
    }

    static func agentBrandNS(for type: AgentType) -> NSColor {
        NSColor(SessionHighlightStyle.agentBrand(for: type))
    }
}
