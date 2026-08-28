import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The starved-frame-clock report (#1084).
///
/// `DisplayLinkDriver` clamps `dt` before the engine sees it, so
/// a clock that stops being serviced is invisible downstream and
/// its symptoms get blamed on whatever code sits nearby — which
/// cost an evening and three wrong hypotheses before this
/// existed. The decision is pure so it can be held here: `fire`
/// needs a real `CADisplayLink` on a real screen, which a suite
/// must not take (tests.md).
@Suite("Frame-clock stall report (#1084)")
struct DisplayLinkStallTests {
    @Test("A healthy frame at any rate reports nothing")
    func healthyFrameIsSilent() {
        // The inverse matters more than the positive: a report
        // that fires on ordinary motion is worse than none,
        // because it buries the real entries. These are the
        // rates this runs at — 120Hz, 60Hz, and ProMotion's
        // slowest advertised cadence — plus a frame at half
        // that again, which is late but not a stall.
        for gap in [1.0 / 120, 1.0 / 60, 1.0 / 24, 0.08] {
            #expect(
                DisplayLinkDriver.stallReport(
                    gap: gap,
                    displayID: 1
                ) == nil
            )
        }
    }

    @Test("A starved clock reports the raw gap and its display")
    func starvedClockReports() {
        // The device numbers this was built from: 42 stalls in
        // ten seconds of held resize, worst 607ms.
        let line = DisplayLinkDriver.stallReport(
            gap: 0.607,
            displayID: 7
        )
        #expect(line == "frame clock stalled 607ms on display 7")
    }
}
