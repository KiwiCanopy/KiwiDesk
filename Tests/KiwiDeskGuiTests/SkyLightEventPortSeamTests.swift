import Foundation
import Testing

/// **The main connection's event port has ONE owner, and the
/// window wake-up is wired at start** (#1877). A notify proc
/// hears nothing until the port is drained, and a second
/// `CFMachPort` on the same port splits the drain, so the border
/// pump and the wake-up both drain through `SkyLightEventPort`.
/// The wake-up's sink is set only by `startWindowServerWakeUp`,
/// so a dropped call leaves AX alone and reds nothing else.
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

    @Test("one owner creates and drains the event port")
    func onePortOwner() throws {
        #expect(
            try hits("CFMachPortCreateWithPort(")
                == ["SkyLightEventPort.swift": 1]
        )
        #expect(
            try hits("\"SLEventCreateNextEvent\"")
                == ["SkyLightEventPort.swift": 1]
        )
        #expect(
            try hits("SkyLightEventPort.shared")
                == [
                    "SkyLightWindowEvents.swift": 1,
                    "SkyLightWindowLifecycle.swift": 1,
                ]
        )
    }

    @Test("the wake-up starts with the workspace observers")
    func wakeUpIsWired() throws {
        var calls = try hits("startWindowServerWakeUp()")
        for (file, count) in try hits("func startWindowServerWakeUp()") {
            calls[file, default: 0] -= count
        }
        #expect(calls.filter { $0.value > 0 } == ["EventLoop+Apps.swift": 1])
        #expect(
            try hits("SkyLightWindowLifecycle.sink =")
                == ["EventLoop+WindowServerWakeUp.swift": 1]
        )
    }
}
