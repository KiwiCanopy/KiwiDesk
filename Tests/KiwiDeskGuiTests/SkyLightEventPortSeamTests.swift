import Foundation
import Testing

/// **The main connection's event port has ONE owner, and the
/// window wake-up is wired at start** (#1877). A notify proc
/// hears nothing until the port is drained, and a second
/// `CFMachPort` on the same port splits the drain, so the border
/// pump and the wake-up both drain through `SkyLightEventPort`.
/// The wake-up starts at boot and stops at teardown; a dropped
/// call leaves the AX path alone and reds nothing else.
@Suite("SkyLight event port seam (#1877)")
struct SkyLightEventPortSeamTests {
    private let root = SourceScan.repoRoot(from: #filePath)
        .appendingPathComponent("Sources/KiwiDeskCore")

    private func hits(_ needle: String) throws -> [String: Int] {
        var found: [String: Int] = [:]
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let count = source.components(separatedBy: needle).count - 1
            if count > 0 { found[file.lastPathComponent] = count }
        }
        return found
    }

    @Test("one owner creates, drains and registers on the port")
    func onePortOwner() throws {
        let owner = ["SkyLightEventPort.swift": 1]
        #expect(try hits("CFMachPortCreateWithPort(") == owner)
        // Resolved by the owner; named once more by the
        // `self_test` row, which resolves nothing (#1889).
        let named = owner.merging(
            ["SkyLightEventPort+SelfTest.swift": 1],
            uniquingKeysWith: +
        )
        #expect(try hits("\"SLEventCreateNextEvent\"") == named)
        #expect(try hits("\"SLSRegisterNotifyProc\"") == named)
        // Both consumers register through the port, and the pump
        // brackets the drain for its synchronous flush.
        #expect(
            try hits("port.register(")
                == [
                    "SkyLightWindowEvents.swift": 1,
                    "SkyLightWindowLifecycle.swift": 1,
                ]
        )
        #expect(
            try hits("port.observeDrain(")
                == ["SkyLightWindowEvents.swift": 1]
        )
    }

    @Test("the wake-up starts at boot and stops at teardown")
    func wakeUpIsWired() throws {
        var calls = try hits("startWindowServerWakeUp()")
        for (file, count) in try hits("func startWindowServerWakeUp()") {
            calls[file, default: 0] -= count
        }
        #expect(
            calls.filter { $0.value > 0 } == ["KiwiCore+Boot.swift": 1]
        )
        #expect(
            try hits("SkyLightWindowLifecycle.start")
                == ["KiwiCore+WindowServerWakeUp.swift": 1]
        )
        #expect(
            try hits("SkyLightWindowLifecycle.stop()")
                == ["KiwiCore+Lifecycle.swift": 1]
        )
    }
}
