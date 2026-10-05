import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// An animation starts on its first frame shown (#1878): the first
/// tick after a start steps one nominal frame instead of being
/// dropped, while later ticks keep their clamped gap. Pure, like
/// the stall report, since `fire` needs a real `CADisplayLink`.
@Suite("Display link first frame (#1878)")
struct DisplayLinkFirstFrameTests {
    @Test("the first tick steps one nominal frame")
    func firstTickSteps() {
        for rate in [120.0, 60.0, 24.0] {
            let dt = DisplayLinkDriver.step(
                now: 10,
                last: nil,
                target: 10 + 1 / rate
            )
            #expect(dt == 10 + 1 / rate - 10, "\(rate) Hz")
        }
    }

    @Test("a first tick with no frame ahead steps nothing")
    func firstTickWithoutTarget() {
        #expect(DisplayLinkDriver.step(now: 10, last: nil, target: 10) == nil)
    }

    @Test("a later tick takes the gap, clamped to a frame")
    func laterTicksClamp() {
        let frame = 0.0078125  // 1/128 s, exact in binary
        #expect(
            DisplayLinkDriver.step(
                now: 10,
                last: 10 - frame,
                target: 10 + frame
            ) == frame
        )
        // A gap after sleep clamps to the 30 Hz floor.
        #expect(
            DisplayLinkDriver.step(now: 10, last: 4, target: 10 + frame)
                == 1.0 / 30
        )
        #expect(DisplayLinkDriver.step(now: 10, last: 10, target: 11) == nil)
    }
}
