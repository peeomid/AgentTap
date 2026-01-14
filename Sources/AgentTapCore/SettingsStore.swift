import Foundation
import Observation

public enum RefreshInterval: Int, CaseIterable, Identifiable {
    case threeSeconds = 3
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case fifteenMinutes = 900

    public var id: Int { rawValue }

    public var seconds: Double? {
        Double(rawValue)
    }

    public var displayName: String {
        switch self {
        case .threeSeconds:
            return "Every 3 seconds"
        case .oneMinute:
            return "Every 1 minute"
        case .twoMinutes:
            return "Every 2 minutes"
        case .fiveMinutes:
            return "Every 5 minutes"
        case .fifteenMinutes:
            return "Every 15 minutes"
        }
    }
}

public enum NotificationSound: String, CaseIterable, Identifiable {
    case `default`
    case glass = "Glass"
    case ping = "Ping"
    case pop = "Pop"
    case none

    public var id: String { rawValue }

    public var storageValue: String { rawValue }

    public var displayName: String {
        switch self {
        case .default: return "Default"
        case .glass: return "Glass"
        case .ping: return "Ping"
        case .pop: return "Pop"
        case .none: return "None"
        }
    }

    public static func options() -> [NotificationSound] {
        Array(allCases)
    }
}

@MainActor
@Observable
public final class SettingsStore {
    public struct ObserverToken: Hashable {
        fileprivate let id: UUID
    }

    public struct Keys {
        public static let notificationsEnabled = "AgentTap.notificationsEnabled"
        public static let refreshInterval = "AgentTap.refreshInterval"
        public static let notificationSound = "AgentTap.notificationSound"
        public static let agjCommand = "AgentTap.agjCommand"
    }

    public var refreshInterval: RefreshInterval {
        didSet {
            defaults.set(refreshInterval.rawValue, forKey: Keys.refreshInterval)
            notifyObservers()
        }
    }

    public var notificationsEnabled: Bool {
        didSet {
            defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled)
            notifyObservers()
        }
    }

    public var notificationSound: NotificationSound {
        didSet {
            defaults.set(notificationSound.storageValue, forKey: Keys.notificationSound)
            notifyObservers()
        }
    }

    public var agjCommand: String {
        didSet {
            defaults.set(agjCommand, forKey: Keys.agjCommand)
            notifyObservers()
        }
    }

    private let defaults: UserDefaults
    private var observers: [UUID: () -> Void] = [:]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let intervalRaw = defaults.integer(forKey: Keys.refreshInterval)
        self.refreshInterval = RefreshInterval(rawValue: intervalRaw) ?? .threeSeconds

        if defaults.object(forKey: Keys.notificationsEnabled) == nil {
            self.notificationsEnabled = true
        } else {
            self.notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        }

        let soundValue = defaults.string(forKey: Keys.notificationSound) ?? NotificationSound.default.storageValue
        self.notificationSound = NotificationSound(rawValue: soundValue) ?? .default

        self.agjCommand = defaults.string(forKey: Keys.agjCommand) ?? ""
    }

    public func addObserver(_ observer: @escaping () -> Void) -> ObserverToken {
        let token = ObserverToken(id: UUID())
        observers[token.id] = observer
        return token
    }

    public func removeObserver(_ token: ObserverToken) {
        observers[token.id] = nil
    }

    private func notifyObservers() {
        observers.values.forEach { $0() }
    }
}
