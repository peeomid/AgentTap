import Foundation

public struct CommandResult: Equatable {
    public let exitCode: Int32
    public let stdout: String
    public let stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public enum CommandRunnerError: LocalizedError, Equatable {
    case binaryNotFound(String)
    case notExecutable(String)
    case failedToRun(String)

    public var errorDescription: String? {
        switch self {
        case .binaryNotFound(let detail):
            return detail
        case .notExecutable(let detail):
            return detail
        case .failedToRun(let detail):
            return detail
        }
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: String, arguments: [String]) async throws -> CommandResult
}

public final class ProcessCommandRunner: CommandRunning, @unchecked Sendable {
    private let agjCommandOverride: () -> String?

    public init(agjCommandOverride: @escaping () -> String?) {
        self.agjCommandOverride = agjCommandOverride
    }

    public func run(_ command: String, arguments: [String]) async throws -> CommandResult {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let env = EnvironmentBuilder.enrichedEnvironment(
                        env: ProcessInfo.processInfo.environment,
                        fileManager: .default,
                        home: FileManager.default.homeDirectoryForCurrentUser.path)

                    let loginPath = LoginShellPathCache.shared.current
                    let resolved = BinaryLocator.resolveAgjBinary(
                        commandOverride: self.agjCommandOverride(),
                        env: env,
                        loginPATH: loginPath,
                        fileManager: .default)

                    guard let resolvedCommand = resolved else {
                        throw CommandRunnerError.binaryNotFound("agj not found on PATH. Install with: pipx install agj")
                    }

                    if !FileManager.default.isExecutableFile(atPath: resolvedCommand) {
                        throw CommandRunnerError.notExecutable("Custom path not executable. Update the path or leave blank to use PATH.")
                    }

                    let process = Process()
                    process.executableURL = URL(fileURLWithPath: resolvedCommand)
                    process.arguments = [command] + arguments
                    process.environment = env

                    let stdoutPipe = Pipe()
                    let stderrPipe = Pipe()
                    process.standardOutput = stdoutPipe
                    process.standardError = stderrPipe

                    try process.run()
                    process.waitUntilExit()

                    let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                    let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

                    let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                    let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                    let result = CommandResult(exitCode: process.terminationStatus, stdout: stdout, stderr: stderr)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
