import Foundation
import Testing

@testable import KiwiDeskCore

/// `service start` / `restart` refuse a translocated copy (#2267):
/// its path dies at relaunch, so the LaunchAgent would never start
/// again. The launchctl calls themselves are not exercised here.
@Suite("Service install refusal")
struct ServiceInstallRefusalTests {
    @Test("only a translocated copy is refused")
    func refusesOnlyTranslocated() {
        #expect(ServiceManager.installRefusal(for: .bundled) == nil)
        #expect(ServiceManager.installRefusal(for: .bare) == nil)
        let refusal = ServiceManager.installRefusal(for: .translocated)
        #expect(refusal?.contains("/Applications") == true)
    }

    /// The plist writer asks the running copy's verdict before it
    /// writes: deleting the check leaves the pure function green.
    @Test("the plist writer consults the running copy first")
    func writerConsultsTheVerdict() throws {
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
        let writer = try #require(
            flat.range(of: "privatestaticfuncwritePlist()")
        )
        let body = flat[writer.upperBound...].prefix(400)
        #expect(
            body.contains(
                "iflet refusal=installRefusal(for:RunningCopy.location)"
                    .replacingOccurrences(of: " ", with: "")
            )
        )
        let check = try #require(body.range(of: "installRefusal("))
        let write = try #require(body.range(of: "plistContent("))
        #expect(check.lowerBound < write.lowerBound)
    }
}
