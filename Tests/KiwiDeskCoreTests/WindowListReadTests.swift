import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A slow public window-list read names its call site and thread
/// (#2634), so a stalled run-loop turn is attributed to the read
/// that held the connection lock. `timed` takes the clock and the
/// sink, so no test swaps a global or waits on a real read.
@Suite("Window-list read attribution (#2634)")
struct WindowListReadTests {
    private func run(
        takes duration: Duration,
        onMain: Bool = true
    ) -> (lines: [String], list: [[String: Any]]?) {
        let base = ContinuousClock.now
        var ticks = [base, base.advanced(by: duration)]
        var lines: [String] = []
        let list = WindowListRead.timed(
            "probe",
            now: { ticks.removeFirst() },
            onMain: onMain,
            log: { lines.append($0) },
            read: { [["id": 1]] }
        )
        return (lines, list)
    }

    @Test("a read at the threshold logs its site, time and thread")
    func slowReadIsNamed() {
        let slow = run(takes: .milliseconds(60))
        #expect(slow.lines == ["window-list read probe: 60 ms main"])
        let edge = run(takes: WindowListRead.slowThreshold)
        #expect(edge.lines.count == 1)
    }

    @Test("an off-main read says so")
    func threadIsNamed() {
        let slow = run(takes: .milliseconds(80), onMain: false)
        #expect(slow.lines == ["window-list read probe: 80 ms off main"])
    }

    @Test("a fast read stays silent and returns the list")
    func fastReadIsSilent() {
        let fast = run(takes: .milliseconds(10))
        #expect(fast.lines.isEmpty)
        #expect(fast.list?.count == 1)
    }

    @Test("a slow read still returns the list")
    func slowReadReturnsTheList() {
        #expect(run(takes: .seconds(1)).list?.count == 1)
    }
}
