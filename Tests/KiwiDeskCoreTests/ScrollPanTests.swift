import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥ + scroll (#1656, rulings 2026-09-29): focus moves one
/// window per swipe (more with long swipes) or per wheel notch, the
/// glide never counted — along a Scrolling row, through a Monocle
/// stack, and in array order on every other layout
/// (`ScrollPanLayoutTests`).
@Suite("Scroll pan gesture", .serialized)
@MainActor
struct ScrollPanTests {
    private static let pan: ScrollChord = [.control, .option]

    /// `count` windows in the active space, in `mode`, focus on
    /// `focus`; the session answers that space under any point.
    private func makeCore(
        _ mode: String,
        windows count: Int = 5,
        focus: WindowID = WindowID(3)
    ) -> (KiwiCore, SpaceID, ScrollPanSession) {
        let core = makeTestCore()
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
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string(mode)]
        )
        core.state.workspaces.focus(focus, in: space)
        let session = ScrollPanSession()
        session.spaceAt = { _, _ in space }
        return (core, space, session)
    }

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        dx: Double = 0,
        dy: Double = 0,
        input: ScrollGestureEvent.Input = .trackpad,
        momentum: Bool = false
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: Self.pan,
            kind: kind,
            input: input,
            delta: CGVector(dx: dx, dy: dy),
            momentum: momentum,
            location: .zero
        )
    }

    private func focused(_ core: KiwiCore) -> WindowID? {
        core.activeSpace?.focused
    }

    private func byLength(_ core: KiwiCore) {
        var base = ScrollGestureBase.defaults
        base.longSwipes = true
        core.applyScrollGestures(base: base, profile: nil)
    }

    private var stride: Double { ScrollGestureBase.defaults.stepDistance }

    @Test("a swipe moves one window, against the fingers")
    func oneWindowPerSwipe() {
        let (core, _, session) = makeCore("scrolling")
        core.handleScrollPan(event(.began), session: session)
        // Fingers left: content left, the NEXT window comes in.
        for _ in 0..<5 {
            core.handleScrollPan(event(.changed, dx: -80), session: session)
        }
        #expect(focused(core) == WindowID(4))
        core.handleScrollPan(event(.ended), session: session)
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(event(.changed, dx: 80), session: session)
        #expect(focused(core) == WindowID(3))
    }

    @Test("long swipes: first window early, then one per distance")
    func longSwipesStep() {
        let (core, _, session) = makeCore("scrolling")
        byLength(core)
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(event(.changed, dx: -30), session: session)
        #expect(focused(core) == WindowID(4))
        core.handleScrollPan(
            event(.changed, dx: -(stride - 1)),
            session: session
        )
        #expect(focused(core) == WindowID(4))
        core.handleScrollPan(event(.changed, dx: -1), session: session)
        #expect(focused(core) == WindowID(5))
    }

    @Test("long swipes: several windows in one event")
    func longSwipe() {
        let (core, _, session) = makeCore("scrolling", focus: WindowID(1))
        byLength(core)
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(event(.changed, dx: -30), session: session)
        core.handleScrollPan(
            event(.changed, dx: -2 * stride),
            session: session
        )
        #expect(focused(core) == WindowID(4))
    }

    @Test("the glide after a lift never moves focus")
    func momentumIgnored() {
        let (core, _, session) = makeCore("scrolling")
        byLength(core)
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(
            event(.changed, dx: -10 * stride, momentum: true),
            session: session
        )
        #expect(focused(core) == WindowID(3))
    }

    @Test("a wheel moves one window per notch, either axis")
    func wheelNotches() {
        let (core, _, session) = makeCore("scrolling")
        core.handleScrollPan(event(.began, input: .wheel), session: session)
        core.handleScrollPan(
            event(.changed, dy: -1, input: .wheel),
            session: session
        )
        core.handleScrollPan(
            event(.changed, dy: -40, input: .wheel),
            session: session
        )
        #expect(focused(core) == WindowID(5))
    }

    @Test("a Monocle Space steps once per gesture")
    func monocleOncePerGesture() {
        let (core, _, session) = makeCore("monocle")
        core.handleScrollPan(event(.began), session: session)
        for _ in 0..<5 {
            core.handleScrollPan(event(.changed, dx: -40), session: session)
        }
        #expect(focused(core) == WindowID(4))
        core.handleScrollPan(event(.ended), session: session)
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(event(.changed, dx: 40), session: session)
        #expect(focused(core) == WindowID(3))
    }

    @Test("a gesture over no Space does nothing")
    func noSpaceUnderPointer() {
        let (core, _, session) = makeCore("scrolling")
        session.spaceAt = { _, _ in nil }
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(
            event(.changed, dx: -5 * stride),
            session: session
        )
        #expect(focused(core) == WindowID(3))
    }

    @Test("an ended gesture stops acting")
    func endedStops() {
        let (core, _, session) = makeCore("scrolling")
        core.handleScrollPan(event(.began), session: session)
        core.handleScrollPan(event(.ended), session: session)
        core.handleScrollPan(
            event(.changed, dx: -5 * stride),
            session: session
        )
        #expect(focused(core) == WindowID(3))
    }

    @Test("bootstrap wires the pan consumer")
    func bootstrapWiresTheHandler() {
        let core = makeTestCore()
        var made = 0
        core.mouse.scroll.makeTap = { _ in
            made += 1
            return nil
        }
        core.mouse.scroll.onLog = { _ in }
        core.mouse.scroll.start()
        core.applyScrollGestures(base: .defaults, profile: nil)
        // A handler-less consumer never makes the tap consume.
        #expect(made > 0)
    }
}
