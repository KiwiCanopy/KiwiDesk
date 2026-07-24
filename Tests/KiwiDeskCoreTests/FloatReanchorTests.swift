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
            force: true
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
            force: true
        )
        #expect(engine.stashOriginal(WindowID(1)) == seeded)
    }

    @Test("Eligibility: floats always, anyone into floating mode")
    func eligibility() {
        // Float-flagged windows re-anchor whatever the target.
        #expect(
            FloatReanchor.eligible(
                isFloating: true,
                targetMode: .bsp
            )
        )
        // A tiled window bound for a floating-MODE space (#498)
        // re-anchors too: that layout assigns no frames, so no
        // retile would ever deliver it to the new display.
        #expect(
            FloatReanchor.eligible(
                isFloating: false,
                targetMode: .floating
            )
        )
        // Tiled window into a tiling space: the layout owns it.
        #expect(
            !FloatReanchor.eligible(
                isFloating: false,
                targetMode: .track
            )
        )
        #expect(
            !FloatReanchor.eligible(
                isFloating: false,
                targetMode: nil
            )
        )
    }
}
