import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥ + a swipe (#3200, owner ruling 2026-11-11): a scroll with a
/// finger phase moves focus the way it goes on every layout without
/// a row, through the arrow keys' step, on the axis its first step
/// locks until the fingers lift; a wheel notch keeps the list walk
/// (`ScrollPanLayoutTests`).
@Suite("Scroll pan swipes", .serialized)
@MainActor
struct ScrollPanSwipeTests {
    /// Four windows in a 2 × 2 grid — 1 2 over 3 4 — on a pinned
    /// display, focus on `focus`.
    private func makeCore(
        focus: WindowID,
        wrap: String = "off"
    ) -> (KiwiCore, ScrollPanSession) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...4 {
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
        core.execute("set_mode", args: [.string(space.raw), .string("grid")])
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

    /// Content follows the fingers, as on a Scrolling row: fingers
    /// left bring the right-hand window in.
    @Test("a swipe steps the way it goes, on both axes")
    func stepsByDirection() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(-80, 0)])
        #expect(focused(core) == WindowID(2))
        gesture(core, session, [(0, -80)])
        #expect(focused(core) == WindowID(4))
        gesture(core, session, [(80, 0)])
        #expect(focused(core) == WindowID(3))
        gesture(core, session, [(0, 80)])
        #expect(focused(core) == WindowID(1))
    }

    /// A list walk would land on 2 here, the next window in order.
    @Test("a vertical swipe never walks the list")
    func notTheList() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(0, -80)])
        #expect(focused(core) == WindowID(3))
    }

    @Test("a wheel notch walks the list")
    func wheelWalks() {
        let (core, session) = makeCore(focus: WindowID(1))
        gesture(core, session, [(0, -80)], input: .wheel)
        #expect(focused(core) == WindowID(2))
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
        gesture(core, session, [(-30, -10), (0, -200), (-2, -200)])
        #expect(focused(core) == WindowID(2))
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
        gesture(core, session, [(-30, 0), (-50, 400)])
        // 1 → 2, then wrapping back to 1 within the screen.
        #expect(focused(core) == WindowID(1))
    }

    @Test("a border with no neighbour bumps, as the keys do")
    func borderBumps() {
        let (core, session) = makeCore(focus: WindowID(2))
        var bumps: [Direction] = []
        core.borders.deadEndProbe = { bumps.append($1) }
        gesture(core, session, [(-80, 0)])
        #expect(focused(core) == WindowID(2))
        #expect(bumps == [.right])
    }
}
