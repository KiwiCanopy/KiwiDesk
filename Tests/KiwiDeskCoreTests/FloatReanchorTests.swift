import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Displays side by side, AX coordinates: main 1920×1055 with a
/// 25 pt menu bar, secondary to its right and smaller.
private let mainBounds = CGRect(
    x: 0,
    y: 25,
    width: 1920,
    height: 1055
)
private let sideBounds = CGRect(
    x: 1920,
    y: 105,
    width: 1440,
    height: 875
)

/// Pure re-anchor math (#444): a float crossing displays keeps
/// its PROPORTIONAL position in the target visible frame (QA:
/// bottom-right must stay bottom-right on a bigger screen),
/// confined inside it.
@Suite("Float re-anchor geometry")
struct FloatReanchorTests {
    @Test("Maps the center to the proportional position")
    func mapsCenterProportionally() {
        // Center at 25% x / 50% y of main: 200×100 around
        // (480, 552.5).
        let frame = CGRect(
            x: 380,
            y: 502.5,
            width: 200,
            height: 100
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds
        )
        // 25% / 50% of the side display: center (2280, 542.5).
        #expect(moved.origin == CGPoint(x: 2180, y: 492.5))
        #expect(moved.size == frame.size)
    }

    @Test("A corner window lands in the same corner")
    func cornerStaysInCorner() {
        // Flush with main's bottom-right; proportionally the
        // window overhangs the smaller display, so the confine
        // snugs it into the SAME corner there.
        let frame = CGRect(
            x: 1620,
            y: 880,
            width: 300,
            height: 200
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds
        )
        #expect(moved.maxX == sideBounds.maxX)
        #expect(moved.maxY == sideBounds.maxY)
        #expect(sideBounds.contains(moved))
        #expect(moved.size == frame.size)
    }

    @Test("Confines into a smaller target display")
    func confinesIntoSmallerTarget() {
        // Near main's bottom-right: the proportional center
        // would overflow the smaller secondary; the confine
        // pulls it inside.
        let frame = CGRect(
            x: 1100,
            y: 460,
            width: 800,
            height: 600
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds
        )
        #expect(sideBounds.contains(moved))
        #expect(moved.size == frame.size)
    }

    @Test("An oversized window pins to the target's min edges")
    func oversizedPinsToMinEdges() {
        let frame = CGRect(x: 0, y: 25, width: 1600, height: 1000)
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds
        )
        #expect(moved.origin == sideBounds.origin)
        #expect(moved.size == frame.size)
    }

    @Test("Same bounds is the identity")
    func sameBoundsIdentity() {
        let frame = CGRect(x: 300, y: 200, width: 640, height: 480)
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: mainBounds
        )
        #expect(moved == frame)
    }

    @Test("scaleSize off leaves the size untouched (default)")
    func scaleOffKeepsSize() {
        let frame = CGRect(
            x: 60,
            y: 100,
            width: 1800,
            height: 800
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds
        )
        #expect(moved.size == frame.size)
    }

    @Test("scaleSize shrinks an oversized float to fit (#502)")
    func scaleShrinksToFit() {
        // 1800 pt wide fits main (1920) but overflows the smaller
        // side display (1440) at full size — the confine would
        // pin it to a corner still overflowing. Scaled by the
        // per-axis ratio it fits outright.
        let frame = CGRect(
            x: 60,
            y: 100,
            width: 1800,
            height: 800
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds,
            scaleSize: true
        )
        // Width ratio 1440/1920 = 0.75 → 1350 (exact).
        #expect(moved.width == 1350)
        #expect(moved.height < frame.height)
        #expect(sideBounds.contains(moved))
    }

    @Test("scaleSize preserves the relative footprint (#502)")
    func scaleKeepsRelativeFootprint() {
        let frame = CGRect(
            x: 480,
            y: 305,
            width: 960,
            height: 400
        )
        let moved = FloatReanchor.target(
            frame: frame,
            from: mainBounds,
            to: sideBounds,
            scaleSize: true
        )
        // Same fraction of each display axis before and after.
        let beforeW = frame.width / mainBounds.width
        let afterW = moved.width / sideBounds.width
        let beforeH = frame.height / mainBounds.height
        let afterH = moved.height / sideBounds.height
        #expect(abs(afterW - beforeW) < 0.0001)
        #expect(abs(afterH - beforeH) < 0.0001)
    }

    @Test("scaleSize with a degenerate source keeps that axis")
    func scaleDegenerateSourceKeepsAxis() {
        // A zero-width source has no ratio to apply: the width is
        // left untouched even when scaling is requested.
        let degenerate = CGRect(x: 0, y: 25, width: 0, height: 1055)
        let frame = CGRect(x: 0, y: 25, width: 400, height: 300)
        let moved = FloatReanchor.target(
            frame: frame,
            from: degenerate,
            to: sideBounds,
            scaleSize: true
        )
        #expect(moved.width == frame.width)
        // Height still scales by its own (valid) ratio.
        #expect(moved.height != frame.height)
    }
}

/// The seeded-capture bookkeeping the re-anchor delivery rides
/// (#444): `seedStash` overwrites, the stash nil-guard then
/// preserves the seed, and `restoreStashed`'s existing machinery
/// applies it.
@Suite("Re-anchor stash seeding")
@MainActor
struct FloatReanchorSeedTests {
    private func makeWindow(
        _ id: UInt32,
        frame: CGRect
    ) -> ManagedWindow {
        ManagedWindow(
            id: WindowID(id),
            pid: 100,
            appName: "TestApp",
            title: "Doc",
            frame: frame,
            isFloating: true
        )
    }

    @Test("seedStash overwrites a pending capture")
    func seedOverwritesCapture() {
        let engine = TilingEngine()
        let old = CGRect(x: 100, y: 125, width: 800, height: 600)
        let window = makeWindow(1, frame: old)
        engine.stash(
            window,
            in: mainBounds,
            corner: .bottomRight,
            force: true,
            capturesOriginal: window.isFloating
        )
        #expect(engine.stashOriginal(WindowID(1)) == old)
        let seeded = CGRect(
            x: 2020,
            y: 205,
            width: 800,
            height: 600
        )
        engine.seedStash(WindowID(1), frame: seeded)
        #expect(engine.stashOriginal(WindowID(1)) == seeded)
    }

    @Test("A later stash keeps the seeded frame as original")
    func stashKeepsSeededOriginal() {
        let engine = TilingEngine()
        let seeded = CGRect(
            x: 2020,
            y: 205,
            width: 800,
            height: 600
        )
        engine.seedStash(WindowID(1), frame: seeded)
        // The target space is inactive: the retile parks the
        // float. The first-capture nil-guard must not replace
        // the seeded original with the pre-park frame.
        let window = makeWindow(
            1,
            frame: CGRect(x: 100, y: 125, width: 800, height: 600)
        )
        engine.stash(
            window,
            in: mainBounds,
            corner: .bottomRight,
            force: true,
            capturesOriginal: window.isFloating
        )
        #expect(engine.stashOriginal(WindowID(1)) == seeded)
    }
}
