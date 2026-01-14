import XCTest
@testable import AgentTapCore

final class PermissionTransitionDetectorTests: XCTestCase {
    func test_detectsNewPrompt() {
        let process = AgentProcess(pid: 1, name: "codex", cmdline: ["codex"], ancestry: [])
        let instance = AgentInstance(id: 1, process: process, session: nil, permissionPrompt: true, permissionReason: nil, permissionOutput: nil)

        let result = PermissionTransitionDetector.transitions(instances: [instance], previous: [:])

        XCTAssertEqual(result.events.count, 1)
        XCTAssertEqual(result.events.first?.instance.id, 1)
        XCTAssertEqual(result.current[instance.sessionKey], true)
    }
}
