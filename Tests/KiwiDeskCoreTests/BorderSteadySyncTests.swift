import AppKit
import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// `FollowSource.syncFrame` (#596 item 3): a steady-state `sync`
/// carries `state.windows[id]?.frame` — the echo-fed frame — so
/// one landing mid-animation snapped the overlay back to where
/// the window was before the motion started, until the next tick
/// dragged it forward again (observed on device as a ~31 pt
/// backward jump). Geometry stands down; everything else `sync`
/// does must not.
@Suite("Border steady-sync animation guard")
@MainActor
struct BorderSteadySyncTests {
    private func spec(
        _ id: UInt32,
        frame: CGRect,
        color: String = "#FF0000"
    ) -> BorderManager.Spec {
        BorderManager.Spec(
            window: WindowID(id),
            frame: frame,
            colorHex: color,
            width: 4,
            cornerStyle: .rounded
        )
    }

    private let start = CGRect(x: 0, y: 0, width: 400, height: 300)
    private let stale = CGRect(x: 5, y: 5, width: 400, height: 300)
    private let tick = CGRect(x: 200, y: 200, width: 400, height: 300)

    @Test("A sync mid-animation holds the last commanded frame")
    func syncHoldsFrameWhileAnimating() {
        let border = BorderManager()
        border.sync([spec(1, frame: start)])
        border.isAnimating = { _ in true }
        // The ring rides the tick out to the target...
        border.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick
        )
        #expect(border.lastFrame(WindowID(1)) == tick)
        // ...and a retile burst / focus change mid-flight must
        // not drag it back to the frame state still holds.
        border.sync([spec(1, frame: stale)])
        #expect(border.lastFrame(WindowID(1)) == tick)
        // Settled, the same sync owns the ring again — this is
        // the pass that heals a window whose app never moved.
        border.isAnimating = { _ in false }
        border.sync([spec(1, frame: stale)])
        #expect(border.lastFrame(WindowID(1)) == stale)
    }

    @Test("Only geometry stands down — sync still recolors")
    func syncStillRecolorsWhileAnimating() {
        let border = BorderManager()
        border.sync([spec(1, frame: start)])
        border.isAnimating = { _ in true }
        border.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick
        )
        border.sync([spec(1, frame: stale, color: "#00FF00")])
        // Held frame, new colour: the recolor rode the same
        // `overlay.update` call the frame guard sits inside, so a
        // guard placed one level too high would have eaten it.
        #expect(border.lastFrame(WindowID(1)) == tick)
        #expect(border.lastColorHex(WindowID(1)) == "#00FF00")
    }

    @Test("Idle and WS-tracked, sync still moves the ring")
    func syncAppliesWhenTrackedAndIdle() {
        let border = BorderManager()
        border.sync([spec(1, frame: start)])
        // Force the stream live AFTER sync (`sync` re-runs the
        // subscription, which resets `skyLightActive`).
        border.skyLightActive = true
        border.isAnimating = { _ in false }
        border.sync([spec(1, frame: stale)])
        // Pins that the stand-down is keyed on OUR animation
        // alone. "Harmonizing" it to also stand down while
        // WS-tracked reads plausible and passes every other test
        // here — and would freeze every tracked ring at its last
        // frame permanently, `sync` being the steady-state path.
        #expect(border.lastFrame(WindowID(1)) == stale)
    }

    @Test("A ring created mid-animation takes the spec frame")
    func newRingMidAnimationUsesSpec() {
        let border = BorderManager()
        border.isAnimating = { _ in true }
        // No held frame to prefer — one tick behind beats no ring.
        border.sync([spec(2, frame: stale)])
        #expect(border.lastFrame(WindowID(2)) == stale)
    }

    @Test("Retirement is unaffected mid-animation")
    func retirementUnaffectedWhileAnimating() {
        let border = BorderManager()
        border.sync([spec(1, frame: start), spec(2, frame: stale)])
        border.isAnimating = { _ in true }
        border.sync([spec(1, frame: start)])
        #expect(border.borderedWindows == [WindowID(1)])
    }
}

/// The sticky mark mirrors the ring through the same shared
/// decision, so the two overlays cannot drift (#285/#594/#596).
@Suite("Sticky mark steady-sync animation guard")
@MainActor
struct StickyMarkSteadySyncTests {
    @Test("A sync mid-animation holds the mark's last frame")
    func markSyncHoldsFrameWhileAnimating() {
        let marks = StickyMarkManager()
        let start = CGRect(x: 0, y: 0, width: 400, height: 300)
        let stale = CGRect(x: 5, y: 5, width: 400, height: 300)
        let tick = CGRect(x: 200, y: 200, width: 400, height: 300)
        marks.sync([
            StickyMarkManager.Spec(window: WindowID(1), frame: start)
        ])
        marks.isAnimating = { _ in true }
        marks.follow(
            WindowID(1),
            windowFrame: tick,
            source: .animationTick
        )
        #expect(marks.lastFrame(WindowID(1)) == tick)
        marks.sync([
            StickyMarkManager.Spec(window: WindowID(1), frame: stale)
        ])
        #expect(marks.lastFrame(WindowID(1)) == tick)
        marks.isAnimating = { _ in false }
        marks.sync([
            StickyMarkManager.Spec(window: WindowID(1), frame: stale)
        ])
        #expect(marks.lastFrame(WindowID(1)) == stale)
    }

    @Test("Idle and WS-tracked, sync still moves the mark")
    func markSyncAppliesWhenTrackedAndIdle() {
        let marks = StickyMarkManager()
        let start = CGRect(x: 0, y: 0, width: 400, height: 300)
        let stale = CGRect(x: 5, y: 5, width: 400, height: 300)
        marks.sync([
            StickyMarkManager.Spec(window: WindowID(1), frame: start)
        ])
        // The mark keeps a live `isWindowServerTracked` closure
        // for `follow`, so the ring's twin mistake — bolting a
        // WS-tracked stand-down onto `sync` — is reachable here
        // too, and would freeze every tracked mark permanently.
        marks.isWindowServerTracked = { _ in true }
        marks.isAnimating = { _ in false }
        marks.sync([
            StickyMarkManager.Spec(window: WindowID(1), frame: stale)
        ])
        #expect(marks.lastFrame(WindowID(1)) == stale)
    }
}
