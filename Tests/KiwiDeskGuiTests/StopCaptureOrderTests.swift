import Foundation
import Testing

/// A stop captures its session BEFORE the gather moves anything
/// (#1864): the gather places every float, and a float's record
/// is the only frame the next launch can give it back. The gather
/// is direct AX IPC no test core can run, so the order is pinned
/// on the shape of `stop()` — the capture spelled ahead of the
/// gather, and handed to the write — rather than by a fixture.
@Suite("A stop captures before it gathers (#1864)")
struct StopCaptureOrderTests {
    @Test("stop() captures, then gathers, then writes that capture")
    func captureLeadsTheGather() throws {
        let body = try SourceScan.functionBody(
            of: "stop",
            in: "KiwiCore+Lifecycle.swift",
            under: "App"
        )
        let capture = try #require(body.range(of: "crash.stopCapture("))
        let gather = try #require(body.range(of: "gatherWindows()"))
        #expect(capture.lowerBound < gather.lowerBound)
        #expect(body.occurrences(of: "crash.stopCapture(") == 1)
        let write = try #require(body.range(of: "captured: captured"))
        #expect(gather.lowerBound < write.lowerBound)
    }
}
