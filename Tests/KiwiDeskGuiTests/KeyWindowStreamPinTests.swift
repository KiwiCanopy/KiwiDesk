import Foundation
import Testing

/// Both `makeTestCore` twins unhook the process-wide key-window
/// stream every core is wired to at bootstrap (#1971's flake):
/// any window turning key in the test process, or a suite posting
/// the notification, re-synced every live core's rings, so an
/// async ring assertion read whichever suite ran beside it. Only
/// `OwnKeyWindowRefreshTests` re-wires — it is the stream's one
/// consumer. A sibling of `MouseButtonSeamGuardTests`' twin
/// clause, one input over.
@Suite("Key-window stream pin")
struct KeyWindowStreamPinTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    @Test("makeTestCore unhooks the key-window stream in both twins")
    func twinsUnhookTheStream() throws {
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let source = try SourceScan.strippedSource(
                at: Self.root.appendingPathComponent(
                    "Tests/\(target)/TestCore.swift"
                )
            )
            #expect(
                source.contains(
                    "core.borders.ownKeyWindowObservers = []"
                )
                    && source.contains(
                        "NotificationCenter.default.removeObserver"
                    ),
                .init(rawValue: "\(target) misses the unhook")
            )
        }
    }

    @Test("only the refresh suite re-wires the stream")
    func oneConsumerRewires() throws {
        var rewiring: [String] = []
        for target in ["KiwiDeskCoreTests", "KiwiDeskGuiTests"] {
            let tree = Self.root.appendingPathComponent(
                "Tests/\(target)"
            )
            for file in try SourceScan.swiftSources(under: tree) {
                let source = try SourceScan.strippedSource(at: file)
                // This file names the call as a needle.
                if file.lastPathComponent != "KeyWindowStreamPinTests.swift",
                    source.contains("wireOwnKeyWindowRefresh()")
                {
                    rewiring.append(file.lastPathComponent)
                }
            }
        }
        #expect(rewiring == ["OwnKeyWindowRefreshTests.swift"])
    }
}
