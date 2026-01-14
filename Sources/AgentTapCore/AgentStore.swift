import Foundation
import Observation

@MainActor
@Observable
public final class AgentStore {
    public struct ObserverToken: Hashable {
        fileprivate let id: UUID
    }

    public private(set) var instances: [AgentInstance] = []
    public private(set) var isRefreshing = false
    public private(set) var lastUpdated: Date?
    public private(set) var health: HealthStatus = .healthy

    public var notificationHandler: (([PermissionTransition]) -> Void)?

    private let client: AGJServing
    private let settings: SettingsStore
    private var refreshTask: Task<Void, Never>?
    private var outputCache: [Int: String] = [:]
    private var permissionState: [String: Bool] = [:]
    private var updateObservers: [UUID: () -> Void] = [:]
    private var settingsObserver: SettingsStore.ObserverToken?

    public init(client: AGJServing, settings: SettingsStore) {
        self.client = client
        self.settings = settings
        self.settingsObserver = settings.addObserver { [weak self] in
            self?.restartRefreshLoop()
        }
    }

    public func start() {
        restartRefreshLoop()
    }

    public func stop() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    public func refresh() async {
        if isRefreshing { return }
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let list = try await client.listInstances()
            instances = list
            lastUpdated = Date()
            health = .healthy
            let transition = PermissionTransitionDetector.transitions(instances: list, previous: permissionState)
            permissionState = transition.current
            if !transition.events.isEmpty {
                notificationHandler?(transition.events)
            }
        } catch let error as AGJClientError {
            switch error {
            case .itermUnavailable:
                health = .itermUnavailable
            case .decodeFailed:
                health = .error("Failed to parse agj output.")
            case .commandFailed(let detail):
                health = .error(detail)
            }
        } catch let error as CommandRunnerError {
            switch error {
            case .binaryNotFound(let detail), .notExecutable(let detail):
                health = .agjMissing(detail)
            case .failedToRun(let detail):
                health = .error(detail)
            }
        } catch {
            health = .error(error.localizedDescription)
        }

        notifyObservers()
    }

    public func output(for instance: AgentInstance) -> String? {
        outputCache[instance.id]
    }

    public func instance(forId id: Int) -> AgentInstance? {
        instances.first { $0.id == id }
    }

    public func instance(forSessionId sessionId: String) -> AgentInstance? {
        instances.first { $0.session?.sessionId == sessionId }
    }

    public func fetchOutput(for instance: AgentInstance) async {
        do {
            let output = try await client.captureOutput(instance: instance, lines: 200)
            outputCache[instance.id] = output
        } catch {
            outputCache[instance.id] = "Failed to capture output: \(error.localizedDescription)"
        }
        notifyObservers()
    }

    public func focus(instance: AgentInstance) async throws {
        try await client.focus(instance: instance)
    }

    public func addObserver(_ observer: @escaping () -> Void) -> ObserverToken {
        let token = ObserverToken(id: UUID())
        updateObservers[token.id] = observer
        return token
    }

    public func removeObserver(_ token: ObserverToken) {
        updateObservers[token.id] = nil
    }

    public func withMutation<T>(_ block: () throws -> T) rethrows -> T {
        let result = try block()
        notifyObservers()
        return result
    }

    private func notifyObservers() {
        updateObservers.values.forEach { $0() }
    }

    private func restartRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.refresh()
                let seconds = self.settings.refreshInterval.seconds ?? 3
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            }
        }
    }
}
