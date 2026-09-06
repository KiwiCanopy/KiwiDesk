import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `resize` on a floating focused window resizes the window
/// itself — in every layout mode, and since #1184 whether the
/// float is the window's own flag or the space's `.floating`
/// mode (`EffectiveFloat.applies`).
@Suite("Floating keyboard resize", .serialized)
@MainActor
struct FloatingResizeCommandTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    /// Two windows in the given mode; w2 focused, floating,
    /// with a known frame. The animation engine is disabled so
    /// `animate` applies the target synchronously through the
    /// observable `apply` hook (the MoveToSpaceTests pattern).
    private func floatingSetup(
        _ core: KiwiCore,
        mode: String,
        applied:
            @escaping @MainActor (
                WindowID, CGRect
            ) -> Void
    ) {
        // Pin the display (#531/#523). Since #1091 the floating
        // resize reads `floatBounds` → `tiler.visibleBounds`, so
        // an unpinned fixture makes every expectation below a
        // function of the host screen — on a narrow runner the
        // low edge pins first and the split changes (code
        // review, 2026-08-29).
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.execute(
            "set_mode",
            args: [.string("1"), .string(mode)]
        )
        for index in 1...2 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        core.state.apply(
            .windowResized(
                WindowID(2),
                CGRect(x: 100, y: 100, width: 600, height: 500)
            )
        )
        core.state.apply(.windowFocused(WindowID(2)))
        core.state.setFloating(WindowID(2), true)
        // Pin the routing: the animated branch must be taken
        // even if the setting's default ever flips.
        core.tiler.settings.animations.onWindowResize = true
        core.tiler.animation.isEnabled = false
        core.tiler.animation.apply = { id, frame, _ in
            applied(id, frame)
        }
    }

    @Test("x widens the floating window; layout untouched")
    func widensTheFloat() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "bsp") { frames[$0] = $1 }
        let ratioBefore = core.tiler.settings.bsp.splitRatioH
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.width == 800)
        #expect(frames[WindowID(2)]?.height == 500)
        // Symmetric since #1091: the delta splits between both
        // edges, so the origin moves back by half. It used to
        // expect an unchanged origin, which was the mouse-drag
        // model the ruling replaced — a chord has no grabbed
        // edge to anchor on. The height is untouched because the
        // ask was on x alone.
        //
        // It lands ON the grow bound's left edge rather than at
        // 0, because that bound reserves the focus ring's reach
        // (device QA): the window would otherwise be grown flush
        // to the screen and have its ring clipped there. Derived
        // rather than pinned at 5 — `border.width` is feel and
        // the owner's to retune (#1021).
        let reach = BorderGeometry.outwardReach(
            width: core.tiler.settings.borderStyle.width
        )
        #expect(frames[WindowID(2)]?.origin.x == reach)
        #expect(
            core.tiler.settings.bsp.splitRatioH == ratioBefore
        )
    }

    @Test("y shrink stops at min_window_size")
    func shrinkFloorsAtMinSize() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "stack") { frames[$0] = $1 }
        core.execute(
            "set_min_window_size",
            args: [.number(300)]
        )
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(-10_000)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.height == 300)
        #expect(frames[WindowID(2)]?.width == 600)
    }

    @Test("works in the floating layout too")
    func worksInFloatingLayout() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "floating") {
            frames[$0] = $1
        }
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(150)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.height == 650)
    }

    @Test("animations off routes through the instant path")
    func instantPathSucceeds() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "bsp") { frames[$0] = $1 }
        core.tiler.settings.animations.onWindowResize = false
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(200)]
        )
        #expect(response.isSuccess)
        // The instant path (cancel + setFrame) bypasses the
        // animate hook entirely.
        #expect(frames.isEmpty)
    }

    /// #1184: the gate asks the EFFECTIVE float, so a member of
    /// a floating-mode space resizes even though the user never
    /// set its flag. It used to refuse here — the same window,
    /// the same space, the same chord, answering differently
    /// depending on a flag that changes nothing about how the
    /// layout treats it.
    ///
    /// Asserts the frame rather than only the verdict: a gate
    /// that succeeded without reaching `resizeFloating` would
    /// pass on `isSuccess` alone.
    @Test("an unflagged focus in the floating layout resizes")
    func unflaggedFocusInFloatingLayoutResizes() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "floating") {
            frames[$0] = $1
        }
        // The very thing the fixture set — this window is
        // ordinary now, and only the space's mode floats it.
        core.state.setFloating(WindowID(2), false)
        let response = core.execute(
            "resize",
            args: [.string("y"), .number(150)]
        )
        #expect(response.isSuccess)
        #expect(frames[WindowID(2)]?.height == 650)
    }

    /// The `default:` arm is still reachable, and this is what
    /// reaches it: a floating space with nothing focused has no
    /// window to resize and none to draw a pill on either.
    @Test("an empty floating space still refuses")
    func emptyFloatingSpaceStillRefuses() {
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("floating")]
        )
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(!response.isSuccess)
        #expect(
            response.error == "resize not supported in floating"
        )
    }

    /// Monocle is untouched by #1184: it PLACES its windows, so
    /// an unflagged member has a layout answer and the refusal
    /// stands. The widening is the floating layout's alone.
    @Test("an unflagged focus in monocle still refuses")
    func unflaggedFocusInMonocleStillRefuses() {
        let core = makeCore()
        var frames: [WindowID: CGRect] = [:]
        floatingSetup(core, mode: "monocle") { frames[$0] = $1 }
        core.state.setFloating(WindowID(2), false)
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(!response.isSuccess)
        #expect(frames.isEmpty)
    }
}
