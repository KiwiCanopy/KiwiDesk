import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A held resize on a FLOATING window travels its whole asked
/// distance where no animation exists to accumulate against
/// (#1090).
///
/// The defect this pins: `resizeFloating` measures from a frame,
/// and its only commanded base was the in-flight animation's
/// target. `AnimationEngine.animate` opens with `guard isEnabled,
/// !reduceMotion()`, so with animations off, under Reduce Motion
/// or with the engine disabled there was no target and it fell
/// back to the echo-fed `state.windows[id].frame` — which in a
/// test never advances at all, and on device advances at echo
/// rate. Measured on device before the fix: 100 asks at ~102 Hz
/// travelled 29% of what they asked for.
///
/// So the suite drives real frames through the real `resize` and
/// asserts the FULL sum. The reverted code reaches
/// `500 + one frame's ask` instead of the sum, because every
/// frame re-bases on the same unchanged frame.
@MainActor
@Suite("Floating hold-glide accumulation (#1090)")
struct FloatGlideAccumulationTests {
    private static let dt = 1.0 / 60

    /// What the press and `frames` glide frames ask for in total,
    /// replayed from the ramp itself rather than hardcoded: the
    /// constants are feel and are the owner's to retune
    /// (`HoldGlide+Ramp`), so a pinned number would red on every
    /// retune and catch no regression (#1021).
    private static func expectedWidth(
        after frames: Int,
        step: Double = 50
    ) -> Double {
        var width = 500.0 + step
        var elapsed = 0.0
        for _ in 0..<frames {
            // The run reads the ramp BEFORE banking the frame.
            let scale = HoldGlide.glideSteps(elapsed: elapsed) * dt
            elapsed += dt
            width += step * scale
        }
        return width
    }

    private func floatFixture() throws -> HoldGlideFixture {
        let f = try HoldGlideFixture(
            body: #"KiwiDesk.resize("x", 50)"#
        )
        f.seedFloating()
        return f
    }

    @Test("A glide accumulates with no animation to lean on")
    func glideAccumulatesWithAnimationsOff() throws {
        let f = try floatFixture()
        // The stand-in for Reduce Motion: all three states take
        // `animate`'s one early return, so the branch under test
        // is identical and no test touches a system preference.
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        let frames = 20
        for _ in 0..<frames {
            try f.frame(Self.dt)
        }
        let expected = Self.expectedWidth(after: frames)
        let width = try #require(f.commandedWidth)
        #expect(abs(Double(width) - expected) < 0.5)
        // The echo never moved, which is the whole point: a base
        // read from it would have stopped one frame past the
        // press. Stated as its own expectation so a regression
        // reads as "it crawled" rather than as a bare number
        // mismatch.
        #expect(f.core.state.windows[WindowID(1)]?.frame.width == 500)
        #expect(
            Double(width)
                > Self.expectedWidth(after: 1) + 100
        )
    }

    @Test("The same run animated lands in the same place")
    func glideAccumulatesWithAnimationsOn() throws {
        let f = try floatFixture()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(true)]
        )
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        let frames = 20
        for _ in 0..<frames {
            try f.frame(Self.dt)
        }
        // The configuration must not change the travel — that
        // equality IS #1090's ruling that Reduce Motion gets no
        // branch of its own. The press animated (it is not a
        // glide write), and the first glide frame cancelled that
        // spring by writing instantly, so the commanded truth is
        // the instant stamp from here on.
        let expected = Self.expectedWidth(after: frames)
        let width = try #require(f.commandedWidth)
        #expect(abs(Double(width) - expected) < 0.5)
        // And a glide frame left no animation resident: the
        // floating path writes instantly now, like every tiled
        // one, so it generates no #611 retarget storm.
        #expect(f.core.tiler.animation.activeCount == 0)
    }

    @Test("The base dies with the hold, so nothing banks")
    func theBaseIsBoundedByTheHold() throws {
        let f = try floatFixture()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        f.registrar.press(keyCode: f.combo.keyCode)
        try f.beginGlide()
        for _ in 0..<10 {
            try f.frame(Self.dt)
        }
        let held = try #require(f.commandedWidth)
        #expect(held > 550)
        f.registrar.release(keyCode: f.combo.keyCode)
        // The property #1056 was protecting, and the whole
        // reason the #881 instant stamp was refused as this base:
        // a record that outlives its run is re-armed by every
        // press that reads it, so an app silently refusing every
        // ask banks commanded growth with no ceiling (#1057).
        // After the release the next press measures from REALITY
        // — the echo-fed frame, still 500 here — not from where
        // the hold got to.
        f.core.execute(
            "resize",
            args: [.string("x"), .number(50)]
        )
        #expect(f.commandedWidth == 550)
    }

    @Test("A press never measures from another press's record")
    func aPressNeverReadsTheRecord() throws {
        // Every floating write records, so that a glide's first
        // frame inherits the arming press's step. The gate that
        // keeps that from becoming the #881 stamp is on the
        // READ: outside a glide step the record is invisible,
        // so two ordinary presses before any echo re-ask the
        // same target instead of compounding one nothing
        // confirmed. `FloatResizeAccumulationTests` pins the
        // same ruling from the command side; this pins the gate
        // that now enforces it.
        let f = try floatFixture()
        f.core.execute(
            "animations.set_on_window_resize",
            args: [.bool(false)]
        )
        for _ in 0..<2 {
            f.core.execute(
                "resize",
                args: [.string("x"), .number(50)]
            )
        }
        #expect(f.commandedWidth == 550)
        // The record IS there — it just cannot be read from
        // outside a glide.
        #expect(
            f.core.tiler.animation.commandedFrame(
                window: WindowID(1),
                includingHeldGlide: true
            )?.width == 550
        )
        #expect(
            f.core.tiler.animation.commandedFrame(
                window: WindowID(1),
                includingHeldGlide: false
            ) == nil
        )
    }

    @Test("The record holds one window, so it cannot leak")
    func theRecordIsSingular() {
        var base = GlideCommandedBase()
        let frame = CGRect(x: 0, y: 0, width: 800, height: 600)
        base.record(WindowID(1), frame: frame)
        #expect(base.frame(for: WindowID(1)) == frame)
        // One hold at a time (a new press ends any previous run),
        // so a second window's entry could only be a leak — and
        // a focus change mid-hold correctly finds nothing and
        // falls back the way a first frame does.
        #expect(base.frame(for: WindowID(2)) == nil)
        base.record(WindowID(2), frame: frame)
        #expect(base.frame(for: WindowID(1)) == nil)
        base.clear()
        #expect(base.frame(for: WindowID(2)) == nil)
    }
}
