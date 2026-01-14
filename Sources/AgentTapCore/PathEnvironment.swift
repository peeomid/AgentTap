import Foundation

public enum PathBuilder {
    public static func effectivePATH(
        env: [String: String],
        loginPATH: [String]?,
        fileManager: FileManager,
        home: String
    ) -> String {
        var components: [String] = []
        if let loginPATH, !loginPATH.isEmpty {
            components.append(contentsOf: loginPATH)
        }
        if let envPath = env["PATH"], !envPath.isEmpty {
            components.append(contentsOf: envPath.split(separator: ":").map(String.init))
        }
        if components.isEmpty {
            components = ["/usr/local/bin", "/opt/homebrew/bin", "/usr/bin", "/bin", "/usr/sbin", "/sbin"]
        }

        let expanded = components.map { path -> String in
            if path.hasPrefix("~") {
                return path.replacingOccurrences(of: "~", with: home)
            }
            return path
        }

        var unique: [String] = []
        for item in expanded where !item.isEmpty {
            if !unique.contains(item) {
                unique.append(item)
            }
        }
        return unique.joined(separator: ":")
    }
}

public enum EnvironmentBuilder {
    public static func enrichedEnvironment(
        env: [String: String],
        fileManager: FileManager,
        home: String
    ) -> [String: String] {
        var result = env
        let loginPath = LoginShellPathCache.shared.current
        let effective = PathBuilder.effectivePATH(env: env, loginPATH: loginPath, fileManager: fileManager, home: home)
        result["PATH"] = effective
        result["__AGENTTAP_PATH__"] = effective
        return result
    }
}

public enum BinaryLocator {
    public static func resolveAgjBinary(
        commandOverride: String?,
        env: [String: String],
        loginPATH: [String]?,
        fileManager: FileManager
    ) -> String? {
        let trimmedOverride = commandOverride?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let trimmedOverride, !trimmedOverride.isEmpty {
            if trimmedOverride.contains(" ") {
                return nil
            }
            if trimmedOverride.hasPrefix("/") {
                return fileManager.fileExists(atPath: trimmedOverride) ? trimmedOverride : nil
            }
        }

        if let envOverride = env["AGJ_CLI_PATH"], !envOverride.isEmpty {
            if envOverride.hasPrefix("/") {
                return fileManager.fileExists(atPath: envOverride) ? envOverride : nil
            }
        }

        let path = PathBuilder.effectivePATH(
            env: env,
            loginPATH: loginPATH,
            fileManager: fileManager,
            home: fileManager.homeDirectoryForCurrentUser.path)
        let candidates = path.split(separator: ":").map(String.init)
        for dir in candidates {
            let candidate = (dir as NSString).appendingPathComponent(trimmedOverride ?? "agj")
            if fileManager.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }
}

public final class LoginShellPathCache: @unchecked Sendable {
    public static let shared = LoginShellPathCache()
    private let lock = NSLock()
    private var captured: [String]?
    private var callbacks: [([String]?) -> Void] = []
    private var isCapturing = false

    private init() {}

    public var current: [String]? {
        lock.lock()
        defer { lock.unlock() }
        return captured
    }

    public func captureOnce(shell: String? = nil, timeout: Double = 1.5, onFinish: (([String]?) -> Void)? = nil) {
        lock.lock()
        if let captured {
            lock.unlock()
            onFinish?(captured)
            return
        }
        if let onFinish {
            callbacks.append(onFinish)
        }
        if isCapturing {
            lock.unlock()
            return
        }
        isCapturing = true
        lock.unlock()

        DispatchQueue.global(qos: .userInitiated).async {
            let result = LoginShellPathCapturer.capture(shell: shell, timeout: timeout)
            self.lock.lock()
            self.captured = result
            let handlers = self.callbacks
            self.callbacks.removeAll()
            self.isCapturing = false
            self.lock.unlock()
            handlers.forEach { $0(result) }
        }
    }
}

public enum LoginShellPathCapturer {
    public static func capture(shell: String? = nil, timeout: Double = 1.5) -> [String]? {
        let shellPath = shell ?? ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: shellPath)
        process.arguments = ["-l", "-c", "echo $PATH"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            process.terminate()
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""
        let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return trimmed.split(separator: ":").map(String.init)
    }
}
