import Foundation

public enum AGJClientError: LocalizedError, Equatable {
    case decodeFailed
    case itermUnavailable
    case commandFailed(String)

    public var errorDescription: String? {
        switch self {
        case .decodeFailed:
            return "Failed to parse agj output."
        case .itermUnavailable:
            return "iTerm2 API unavailable."
        case .commandFailed(let detail):
            return detail
        }
    }
}

public protocol AGJServing: Sendable {
    func listInstances() async throws -> [AgentInstance]
    func focus(instance: AgentInstance) async throws
    func captureOutput(instance: AgentInstance, lines: Int?) async throws -> String
}

public final class AGJClient: AGJServing, @unchecked Sendable {
    private let runner: CommandRunning

    public init(runner: CommandRunning) {
        self.runner = runner
    }

    public func listInstances() async throws -> [AgentInstance] {
        let result = try await runner.run("list", arguments: ["--json", "--with-path"])
        if result.exitCode == 1, result.stdout.contains("No matching instances") {
            return []
        }
        if result.exitCode == 3 {
            throw AGJClientError.itermUnavailable
        }
        if result.exitCode != 0 {
            let detail = result.stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            throw AGJClientError.commandFailed(detail.isEmpty ? "agj failed to run." : detail)
        }
        let data = Data(result.stdout.utf8)
        do {
            return try JSONDecoder().decode([AgentInstance].self, from: data)
        } catch {
            throw AGJClientError.decodeFailed
        }
    }

    public func focus(instance: AgentInstance) async throws {
        guard let sessionId = instance.session?.sessionId else {
            throw AGJClientError.commandFailed("No iTerm session mapped for selection.")
        }
        let result = try await runner.run("focus", arguments: ["--session", sessionId])
        if result.exitCode == 3 { throw AGJClientError.itermUnavailable }
        if result.exitCode != 0 { throw AGJClientError.commandFailed(result.stderr) }
    }

    public func captureOutput(instance: AgentInstance, lines: Int?) async throws -> String {
        guard let sessionId = instance.session?.sessionId else {
            throw AGJClientError.commandFailed("No iTerm session mapped for selection.")
        }
        var args = ["--session", sessionId]
        if let lines {
            args.append(contentsOf: ["--lines", String(lines)])
        }
        let result = try await runner.run("capture", arguments: args)
        if result.exitCode == 3 { throw AGJClientError.itermUnavailable }
        if result.exitCode != 0 { throw AGJClientError.commandFailed(result.stderr) }
        return result.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
