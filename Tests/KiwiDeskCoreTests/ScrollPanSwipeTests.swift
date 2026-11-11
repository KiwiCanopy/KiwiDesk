import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥ + a swipe (#3200, owner rulings 2026-11-11): a scroll with a
/// finger phase moves focus the way the fingers go on every layout
/// without a row, through the arrow keys' step, on the axis its
/// first step locks until the fingers lift; a wheel notch keeps the
/// list walk (`ScrollPanLayoutTests`). Deltas here are in the
/// natural convention the router hands on: their sign is the
/// fingers'.
@Suite("Scroll pan swipes", .serialized)
@MainActor
struct ScrollPanSwipeTests {
    /// `count` windows in `mode` — by default a 2 × 2 grid, 1 2
    /// over 3 4 — on a pinned display, focus on `focus`.
    private func makeCore(
        _ mode: String = "grid",
        windows count: Int = 4,
        focus: WindowID,
        wrap: String = "off"
    ) -> (KiwiCore, ScrollPanSession) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(900_000 + id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        core.execute("set_focus_wrap", args: [.string(wrap)])
        core.state.workspaces.focus(focus, in: space)
        let session = ScrollPanSession()
        session.spaceAt = { _, _ in space }
        return (core, session)
    }

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        _ dx: Double = 0,
        _ dy: Double = 0,
        input: ScrollGestureEvent.Input = .trackpad,
        time: Double = 0
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: [.control, .option],
            kind: kind,
            input: input,
            delta: CGVector(dx: dx, dy: dy),
            momentum: false,
            location: .zero,
            time: time
        )
    }

    /// One gesture: a begin, each delta in turn, an end.
    private func gesture(
        _ core: KiwiCore,
        _ session: ScrollPanSession,
        _ deltas: [(Double, Double)],
        input: ScrollGestureEvent.Input = .trackpad
    ) {
        core.handleScrollPan(event(.began, input: input), session: session)
        for (index, delta) in deltas.enumerated() {
            core.handleScrollPan(
                event(
                    .changed,
                    delta.0,
                    delta.1,
                    input: input,
                    time: Double(index)
                ),
                session: session
            )
        }
        core.handleScrollPan(event(.ended, input: input), session: session)
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.activeSpace?.focused
    }

    /// Focus follows the fingers: fingers right focus the
    /// right-hand window.
    @Test("a swipe steps the way the fingers go, on both axes")
    func stepsByDirection() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(80, 0)])
        #expect(focused(core) == WindowID(2))
        gesture(core, session, [(0, 80)])
        #expect(focused(core) == WindowID(4))
        gesture(core, session, [(-80, 0)])
        #expect(focused(core) == WindowID(3))
        gesture(core, session, [(0, -80)])
        #expect(focused(core) == WindowID(1))
    }

    /// A list walk would land on 2 here, the next window in order.
    @Test("a vertical swipe never walks the list")
    func notTheList() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(0, 80)])
        #expect(focused(core) == WindowID(3))
    }

    /// From 2, up is a wall and down is 4; only the list gives 3.
    @Test("a wheel notch walks the list")
    func wheelWalks() {
        let (core, session) = makeCore(focus: WindowID(2))
        gesture(core, session, [(0, -80)], input: .wheel)
        #expect(focused(core) == WindowID(3))
    }

    /// The axis is the one the travel so far fired on, not the
    /// last event's: mostly-down travel, then a mostly-sideways
    /// event that crosses the threshold, steps down.
    @Test("the lock takes the axis of the travel that fired")
    func lockReadsTheTravel() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(2, 20), (20, 10)])
        #expect(focused(core) == WindowID(3))
    }

    /// The first step locks the horizontal axis; the larger
    /// vertical travel after it is no step, nor a second axis.
    @Test("the first step locks the axis until the lift")
    func axisLocks() {
        let (core, session) = makeCore(focus: WindowID(1))
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        base.stepDistance = 10
        core.applyScrollGestures(base: base, profile: nil)
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        gesture(core, session, [(30, 10), (0, 200), (2, 200)])
        #expect(focused(core) == WindowID(2))
        #expect(bumps.isEmpty)
    }

    /// Long swipes repeat along the locked axis.
    @Test("a long swipe repeats along the locked axis")
    func longSwipeRepeats() {
        let (core, session) = makeCore(
            focus: WindowID(1),
            wrap: "this_screen"
        )
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        base.stepDistance = 50
        core.applyScrollGestures(base: base, profile: nil)
        gesture(core, session, [(30, 0), (50, 400)])
        // 1 → 2, then wrapping back to 1 within the screen.
        #expect(focused(core) == WindowID(1))
    }

    /// Stack: master 1 beside 2 over 3. A list walk from 3 would
    /// land on 2; the swipe goes left, to the master.
    @Test("a Stack swipe reaches the master beside it")
    func stackStepsLeft() {
        let (core, session) = makeCore(
            "stack",
            windows: 3,
            focus: WindowID(3)
        )
        gesture(core, session, [(-80, 0)])
        #expect(focused(core) == WindowID(1))
    }

    @Test("a border with no neighbour bumps, as the keys do")
    func borderBumps() {
        let (core, session) = makeCore(focus: WindowID(2))
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        gesture(core, session, [(80, 0)])
        #expect(focused(core) == WindowID(2))
        #expect(bumps == [.right])
    }
}
