import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// ⌃⌥ + scroll beyond the Scrolling row (#1656, owner ruling
/// 2026-09-29): a held chord always does something — every other
/// layout steps through its windows in array order, wrapping — and
/// no step moves the pointer, Monocle's flip door included.
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
                    location: .zero
                ),
                session: session
            )
        }
    }

    @Test(
        "every other layout steps in array order, wrapping",
        arguments: ["bsp", "stack", "grid"]
    )
    func otherLayoutsStep(mode: String) {
        let (core, session) = makeCore(mode, focus: WindowID(2))
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(3))
        swipe(core, session, dx: -80)
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(1))
        swipe(core, session, dx: 80)
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
        swipe(core, session, dx: -80)
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
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(warps == 0)
    }

    /// A flip still owes its focus when the next step reads the
    /// anchor: the step lands it first, so it starts from there.
    @Test("a Monocle step lands a flip's owed focus first")
    func owedFocusLandsFirst() {
        let (core, session) = makeCore("monocle", focus: WindowID(2))
        core.pendingMonocleFocus = (
            from: WindowID(2),
            to: WindowID(3),
            warp: false
        )
        swipe(core, session, dx: -80)
        #expect(core.activeSpace?.focused == WindowID(4))
        #expect(core.pendingMonocleFocus == nil)
    }

    /// The owed landing honours the warp the step recorded.
    @Test("an owed landing warps only when its step did")
    func owedLandingKeepsWarp() {
        for warp in [false, true] {
            let (core, _) = makeCore("monocle", focus: WindowID(2))
            core.tiler.settings.mouse.followsFocus = true
            var warps = 0
            core.pointerWarp = { _ in warps += 1 }
            core.pendingMonocleFocus = (
                from: WindowID(2),
                to: WindowID(3),
                warp: warp
            )
            core.runPendingMonocleFocus()
            #expect(warps == (warp ? 1 : 0))
        }
    }
}
