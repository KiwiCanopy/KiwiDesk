import Foundation
import Testing

@testable import KiwiDeskCore

/// `service stop` deletes the LaunchAgent plist, which launchd
/// otherwise loads again at the next login (#3538). The launchctl
/// calls themselves are not exercised here.
@Suite("Service stop removes the agent")
struct ServiceStopRemovesAgentTests {
    private func scratchPlist() throws -> URL {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
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

    /// Both of `stop()`'s branches delete the agent, the loaded one
    /// only after its bootout: deleting either call leaves the pure
    /// function green.
    @Test("stop deletes the agent in both branches")
    func stopCallsTheRemoval() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(
            contentsOf: root.appendingPathComponent(
                "Sources/KiwiDeskCore/Service/ServiceManager.swift"
            ),
            encoding: .utf8
        )
        let flat = source.split(whereSeparator: \.isWhitespace)
            .joined()
        let start = try #require(
            flat.range(of: "publicstaticfuncstop()->Outcome{")
        )
        let end = try #require(
            flat[start.upperBound...].range(
                of: "publicstaticfuncrestart()"
            )
        )
        let body = flat[start.upperBound..<end.lowerBound]
        let call = "removeAgent(at:agentURL)"
        let parts = body.components(separatedBy: call)
        #expect(parts.count == 3, "stop() calls removeAgent twice")
        let unloaded = try #require(body.range(of: "guardisLoaded()"))
        let bootout = try #require(body.range(of: "\"bootout\""))
        let first = try #require(body.range(of: call))
        let last = try #require(
            body.range(of: call, options: .backwards)
        )
        #expect(unloaded.lowerBound < first.lowerBound)
        #expect(first.upperBound < bootout.lowerBound)
        #expect(bootout.upperBound < last.lowerBound)
    }
}
