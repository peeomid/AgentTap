import Foundation

public struct PermissionTransition: Equatable {
    public let index: Int
    public let instance: AgentInstance

    public init(index: Int, instance: AgentInstance) {
        self.index = index
        self.instance = instance
    }
}

public enum PermissionTransitionDetector {
    public static func transitions(
        instances: [AgentInstance],
        previous: [String: Bool]
    ) -> (current: [String: Bool], events: [PermissionTransition]) {
        var current: [String: Bool] = [:]
        var events: [PermissionTransition] = []

        for (idx, instance) in instances.enumerated() {
            let key = instance.sessionKey
            let isPrompt = instance.permissionPrompt == true
            current[key] = isPrompt

            let wasPrompt = previous[key] ?? false
            if isPrompt && !wasPrompt {
                events.append(PermissionTransition(index: idx, instance: instance))
            }
        }

        return (current, events)
    }
}
