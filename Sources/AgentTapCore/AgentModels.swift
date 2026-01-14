import Foundation

public struct AgentProcess: Codable, Equatable, Sendable {
    public let pid: Int
    public let name: String
    public let cmdline: [String]
    public let ancestry: [Int]

    public init(pid: Int, name: String, cmdline: [String], ancestry: [Int]) {
        self.pid = pid
        self.name = name
        self.cmdline = cmdline
        self.ancestry = ancestry
    }
}

public struct AgentSession: Codable, Equatable, Sendable {
    public let sessionId: String
    public let tabId: String
    public let windowId: String
    public let pid: Int?
    public let title: String?
    public let path: String?

    public init(sessionId: String, tabId: String, windowId: String, pid: Int?, title: String?, path: String?) {
        self.sessionId = sessionId
        self.tabId = tabId
        self.windowId = windowId
        self.pid = pid
        self.title = title
        self.path = path
    }

    enum CodingKeys: String, CodingKey {
        case sessionId = "session_id"
        case tabId = "tab_id"
        case windowId = "window_id"
        case pid
        case title
        case path
    }
}

public struct AgentInstance: Codable, Identifiable, Equatable, Sendable {
    public let id: Int
    public let process: AgentProcess
    public let session: AgentSession?
    public let permissionPrompt: Bool?
    public let permissionReason: String?
    public let permissionOutput: String?

    public init(
        id: Int,
        process: AgentProcess,
        session: AgentSession?,
        permissionPrompt: Bool?,
        permissionReason: String?,
        permissionOutput: String?
    ) {
        self.id = id
        self.process = process
        self.session = session
        self.permissionPrompt = permissionPrompt
        self.permissionReason = permissionReason
        self.permissionOutput = permissionOutput
    }

    public var displayName: String {
        let base = agentTypeName
        return base
    }

    public var agentTypeName: String {
        let lower = (process.name + " " + process.cmdline.joined(separator: " ")).lowercased()
        if lower.contains("codex") { return "Codex" }
        if lower.contains("claude") { return "Claude" }
        if lower.contains("cursor") { return "Cursor" }
        if lower.contains("aider") { return "Aider" }
        if lower.contains("continue") { return "Continue" }
        return process.name.capitalized
    }

    public var agentLabel: String {
        if let sessionTitle = session?.title, !sessionTitle.isEmpty {
            return "\(agentTypeName) · \(sessionTitle)"
        }
        return agentTypeName
    }

    public var displayPath: String? {
        if let path = session?.path, !path.isEmpty {
            return path
        }
        return nil
    }

    public var shortPath: String? {
        guard let path = displayPath else { return nil }
        return path.replacingOccurrences(of: FileManager.default.homeDirectoryForCurrentUser.path, with: "~")
    }

    public var needsAttention: Bool {
        permissionPrompt == true
    }

    public var permissionStatusText: String {
        if permissionPrompt == true { return "Permission required" }
        if permissionPrompt == false { return "No prompt" }
        return "Unknown"
    }

    public var sessionKey: String {
        if let sessionId = session?.sessionId, !sessionId.isEmpty {
            return sessionId
        }
        return String(process.pid)
    }

    enum CodingKeys: String, CodingKey {
        case id
        case process
        case session
        case permissionPrompt = "permission_prompt"
        case permissionReason = "permission_reason"
        case permissionOutput = "permission_output"
    }
}

public enum HealthStatus: Equatable, Sendable {
    case healthy
    case agjMissing(String)
    case itermUnavailable
    case error(String)

    public var message: String? {
        switch self {
        case .healthy:
            return nil
        case .agjMissing(let detail):
            return detail
        case .itermUnavailable:
            return "iTerm2 API unavailable."
        case .error(let detail):
            return detail
        }
    }
}
