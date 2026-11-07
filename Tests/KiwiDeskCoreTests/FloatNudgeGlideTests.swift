import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A held `move_floating` chord glides (#2972), through the real
/// binding and the real verb: it accumulates from the commanded
/// record, since no echo arrives and no animation exists, and its
/// stop at the region ends the run in silence (#3017).
@MainActor
@Suite("Move floating hold-glide")
struct FloatNudgeGlideTests {
    private static let dt = 1.0 / 60

    private func fixture(step: Double = 10) throws -> HoldGlideFixture {
        let f = try HoldGlideFixture(
            body: "KiwiDesk.move_floating(\"x\", \(step))"
        )
        f.seedFloating()
        return f
    }

    private func commandedX(_ f: HoldGlideFixture) -> CGFloat? {
        f.core.tiler.animation.commandedFrame(
            window: WindowID(1),
            includingHeldGlide: true
        )?.minX
    }

    @Test("a hold accumulates the ramp's whole distance")
    func accumulates() throws {
        let f = try fixture()
        f.registrar.press(keyCode: f.combo.keyCode)
        expectEqual(commandedX(f), 110)
        try f.beginGlide()
        var expected = 110.0
        var elapsed = 0.0
        for _ in 0..<20 {
            let scale = HoldGlide.glideSteps(elapsed: elapsed) * Self.dt
            elapsed += Self.dt
            expected += 10 * scale
            try f.frame(Self.dt)
        }
        let x = try #require(commandedX(f))
        #expect(abs(Double(x) - expected) < 0.5)
        #expect(Double(x) > 120)
        expectEqual(f.core.state.windows[WindowID(1)]?.frame.minX, 100)
    }

    @Test("the stop at the region ends the run, with no cue")
    func stopEndsTheRun() throws {
        var cues: [ResizeRefusal] = []
        // 1200 wide, 500 wide window: the wall is x = 700.
        let f = try fixture(step: 200)
        f.core.borders.onResizeRefusal = { cues.append($0) }
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        #expect(f.core.keys.isGliding)
        for _ in 0..<600 where f.core.keys.isGliding {
            try f.frame(Self.dt)
        }
        #expect(!f.core.keys.isGliding)
        expectEqual(commandedX(f), 700)
        #expect(
            f.core.tiler.recentInstantTarget(WindowID(1))?.minX == 700
        )
        #expect(cues.isEmpty)
    }

    /// The nudge-sized hold, on a fast screen, where every step is a
    /// fraction of a point: the wall still ends the run.
    @Test("a small delta's hold ends at the wall too")
    func smallDeltaEnds() throws {
        let f = try fixture(step: 1)
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        f.core.state.apply(
            .windowResized(
                WindowID(1),
                CGRect(x: 700, y: 100, width: 500, height: 400)
            )
        )
        f.core.tiler.animation.clearGlideCommanded()
        for _ in 0..<5 where f.core.keys.isGliding {
            try f.frame(1.0 / 120)
        }
        #expect(!f.core.keys.isGliding)
    }

    @Test("a press at the wall cues and arms no hold")
    func pressAtTheWall() throws {
        var cues: [ResizeRefusal] = []
        let f = try fixture(step: 700)
        f.core.borders.onResizeRefusal = { cues.append($0) }
        f.registrar.press(keyCode: f.combo.keyCode)
        expectEqual(commandedX(f), 700)
        #expect(
            cues == [.moveAtBoundary(WindowID(1), direction: .right)]
        )
        #expect(f.ticks.isEmpty)
    }
}
