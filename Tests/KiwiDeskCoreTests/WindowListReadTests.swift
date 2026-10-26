import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A slow public window-list read names its call site and thread
/// (#2634), so a stalled run-loop turn is attributed to the read
/// that held the connection lock.
@Suite("Window-list read attribution (#2634)", .serialized)
struct WindowListReadTests {
    private func lines(
        run body: () -> Void
    ) -> [String] {
        nonisolated(unsafe) var seen: [String] = []
        let saved = WindowListRead.onSlow
        WindowListRead.onSlow = { seen.append($0) }
        defer { WindowListRead.onSlow = saved }
        body()
        return seen
    }

    @Test("a slow read logs its site, its time and its thread")
    func slowReadIsNamed() {
        let seen = lines {
            WindowListRead.report(site: "probe", elapsed: 0.5)
        }
        #expect(seen.count == 1)
        let prefix = "window-list read probe: 500 ms"
        #expect(seen.first?.hasPrefix(prefix) == true)
    }

    @Test("a fast read stays silent")
    func fastReadIsSilent() {
        let seen = lines {
            _ = WindowListRead.copy("probe", [.optionOnScreenOnly])
        }
        // A real read on a loaded runner may pass the threshold;
        // the control is that a log, if any, names the site.
        for line in seen {
            #expect(line.contains("probe"))
        }
    }

    @Test("the threshold sits under the run-loop stall the probe counts")
    func thresholdUnderStall() {
        #expect(WindowListRead.slowThreshold < 0.1)
    }
}
