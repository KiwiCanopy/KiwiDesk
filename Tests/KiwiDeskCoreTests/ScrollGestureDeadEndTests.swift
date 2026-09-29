import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A scroll gesture that lands on nothing bumps the ring, as the
/// arrow keys do at a dead end (#436; owner ruling 2026-09-29):
/// once per event, toward the step, never a pill — and nothing
/// where the step moved.
@Suite("Scroll gesture dead ends", .serialized)
@MainActor
struct ScrollGestureDeadEndTests {
    private typealias Bump = (window: WindowID, direction: Direction)

    /// `count` windows in the active space, in `mode`, wrap off,
    /// focus on `focus`; every bump recorded.
    private func makeCore(
        _ mode: String,
        windows count: Int = 3,
        focus: WindowID
    ) -> (KiwiCore, ScrollPanSession, () -> [Bump]) {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(id)),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute("set_mode", args: [.string(space.raw), .string(mode)])
        for verb in ["scroll.set_wrap_focus", "monocle.set_wrap_focus"] {
            core.execute(verb, args: [.bool(false)])
        }
        core.state.workspaces.focus(focus, in: space)
        var bumps: [Bump] = []
        core.borders.deadEndProbe = { bumps.append(($0, $1)) }
        let session = ScrollPanSession()
        session.spaceAt = { _, _ in space }
        return (core, session, { bumps })
    }

    private func swipe(
        _ core: KiwiCore,
        _ session: ScrollPanSession,
        dx: Double
    ) {
        for kind in [ScrollGestureEvent.Kind.began, .changed, .ended] {
            core.handleScrollPan(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: kind,
                    input: .trackpad,
                    delta: CGVector(dx: kind == .changed ? dx : 0, dy: 0),
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
                session: session
            )
        }
    }

    @Test(
        "a row end with wrap off bumps toward the step",
        arguments: ["scrolling", "monocle"]
    )
    func rowEndBumps(mode: String) {
        let (core, session, bumps) = makeCore(mode, focus: WindowID(3))
        // Fingers left: the NEXT window, past the last.
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(bumps().map(\.window) == [WindowID(3)])
        #expect(bumps().map(\.direction) == [.right])
    }

    @Test("a step that moves bumps nothing")
    func movedIsSilent() {
        let (core, session, bumps) = makeCore("scrolling", focus: WindowID(2))
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(bumps().isEmpty)
    }

    @Test("a lone window bumps on any layout")
    func loneWindowBumps() {
        let (core, session, bumps) = makeCore(
            "bsp",
            windows: 1,
            focus: WindowID(1)
        )
        swipe(core, session, dx: 80)
        #expect(bumps().map(\.direction) == [.left])
    }

    /// A long swipe asking for several windows past the end bumps
    /// once, not per window it could not take.
    @Test("one event bumps once")
    func oneBumpPerEvent() {
        let (core, session, bumps) = makeCore("scrolling", focus: WindowID(2))
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        base.stepDistance = 10
        core.applyScrollGestures(base: base, profile: nil)
        for (kind, dx) in [
            (ScrollGestureEvent.Kind.began, 0.0), (.changed, -30),
            (.changed, -200),
        ] {
            core.handleScrollPan(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: kind,
                    input: .trackpad,
                    delta: CGVector(dx: dx, dy: 0),
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
                session: session
            )
        }
        // The first window moved; the next twenty had nowhere.
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(bumps().count == 1)
    }

    /// The arrow keys' own path: a floating focus on a row reaches
    /// the tiled window beside it rather than bumping — the float
    /// is in no row, which the row step alone read as a wall.
    @Test(
        "a floating focus steps as the arrow keys do",
        arguments: ["scrolling", "monocle"]
    )
    func floatFocusFollowsTheKeys(mode: String) {
        func setUp() -> (KiwiCore, ScrollPanSession, () -> [Bump]) {
            let (core, session, bumps) = makeCore(mode, focus: WindowID(1))
            let space = core.state.workspaces.space(of: WindowID(1))!
            core.state.windows.setFloating(WindowID(3), true)
            core.state.apply(
                .windowMoved(
                    WindowID(3),
                    CGRect(x: 20, y: 400, width: 200, height: 200)
                )
            )
            core.state.workspaces.focus(WindowID(3), in: space)
            return (core, session, bumps)
        }
        let (keys, _, keyBumps) = setUp()
        keys.execute("focus", args: [.string("right")])
        let (gesture, session, bumps) = setUp()
        swipe(gesture, session, dx: -80)
        #expect(
            gesture.activeSpace?.focused == keys.activeSpace?.focused
        )
        #expect(bumps().count == keyBumps().count)
        #expect(gesture.activeSpace?.focused != WindowID(3))
    }
}
