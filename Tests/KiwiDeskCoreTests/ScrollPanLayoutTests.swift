import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥ + scroll beyond the Scrolling row (#1656, owner ruling
/// 2026-09-29): a held chord always does something — a wheel walks
/// every other layout's windows in array order, wrapping (#3200;
/// a swipe is `ScrollPanSwipeTests`') — and no step moves the
/// pointer, Monocle's flip door included.
@Suite("Scroll pan on other layouts", .serialized)
@MainActor
struct ScrollPanLayoutTests {
    private func makeCore(
        _ mode: String,
        focus: WindowID = WindowID(3)
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
        return (core, session)
    }

    private func swipe(
        _ core: KiwiCore,
        _ session: ScrollPanSession,
        dx: Double,
        input: ScrollGestureEvent.Input = .trackpad
    ) {
        for kind in [ScrollGestureEvent.Kind.began, .changed, .ended] {
            core.handleScrollPan(
                ScrollGestureEvent(
                    chord: [.control, .option],
                    kind: kind,
                    input: input,
                    delta: CGVector(dx: kind == .changed ? dx : 0, dy: 0),
                    momentum: false,
                    location: .zero,
                    time: 0
                ),
                session: session,
                directional: true
            )
        }
    }

    @Test(
        "a wheel steps every other layout in array order, wrapping",
        arguments: ["bsp", "stack", "grid"]
    )
    func otherLayoutsStep(mode: String) {
        let (core, session) = makeCore(mode, focus: WindowID(2))
        swipe(core, session, dx: -80, input: .wheel)
        #expect(core.activeSpace?.focused == WindowID(3))
        swipe(core, session, dx: -80, input: .wheel)
        swipe(core, session, dx: -80, input: .wheel)
        #expect(core.activeSpace?.focused == WindowID(1))
        swipe(core, session, dx: 80, input: .wheel)
        #expect(core.activeSpace?.focused == WindowID(4))
    }

    /// A fullscreen member sits on a Desktop nobody shows, where
    /// the focus gate refuses it: the step passes it by.
    @Test("a fullscreen member is stepped past")
    func fullscreenIsSkipped() {
        let (core, session) = makeCore("bsp", focus: WindowID(2))
        core.state.apply(
            .windowFullscreenChanged(WindowID(3), isFullscreen: true)
        )
        swipe(core, session, dx: -80, input: .wheel)
        #expect(core.activeSpace?.focused == WindowID(4))
    }

    @Test(
        "no step moves the pointer",
        arguments: ["scrolling", "monocle", "bsp"]
    )
    func noWarp(mode: String) {
        let (core, session) = makeCore(mode)
        core.tiler.settings.mouse.followsFocus = true
        var warps = 0
        core.pointerWarp = { _ in warps += 1 }
        #expect(core.mouseWarpEligible(WindowID(4)))
        // A swipe on BSP goes by direction; a wheel walks to 4.
        swipe(
            core,
            session,
            dx: -80,
            input: mode == "bsp" ? .wheel : .trackpad
        )
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(warps == 0)
    }
}
