import Foundation
import Testing

@testable import KiwiDeskCore

/// `service stop` deletes the LaunchAgent plist, which launchd
/// otherwise loads again at the next login (#3538). The launchctl
/// calls themselves are not exercised here; the wiring is
/// `InPlaceRestartWiringTests` ▸ `stopRemovesTheAgent`.
@Suite("Service stop removes the agent")
struct ServiceStopRemovesAgentTests {
    private func scratchPlist() throws -> URL {
        let dir =
            testTemporaryDirectory
            .appendingPathComponent("agent-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true
        )
        return dir.appendingPathComponent("agent.plist")
    }

    @Test("an existing plist is deleted")
    func deletesThePlist() throws {
        let url = try scratchPlist()
        try "plist".write(to: url, atomically: true, encoding: .utf8)
        #expect(ServiceManager.removeAgent(at: url) == nil)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test("a missing plist is success")
    func missingIsSuccess() throws {
        let url = try scratchPlist()
        #expect(ServiceManager.removeAgent(at: url) == nil)
    }
}
