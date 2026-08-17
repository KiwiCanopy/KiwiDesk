import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-wrap-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Boots `count` windows into the active space, switches it to
/// scrolling, and focuses `focus`. Returns the space id.
@MainActor
@discardableResult
private func makeScrollingSpace(
    _ core: KiwiCore,
    windows count: Int,
    focus: WindowID
) -> SpaceID {
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
        args: [.string(space.raw), .string("scrolling")]
    )
    core.state.workspaces.focus(focus, in: space)
    return space
}

/// Puts the animation engine mid-flight deterministically: a
/// dummy animation on an unmanaged window. Returns false when no
/// display is available — callers skip, per the screen-guard
/// convention shared with `ScrollingDeferredRaiseTests`.
@MainActor
private func startDummyPan(_ core: KiwiCore) -> Bool {
    guard let screen = NSScreen.main else { return false }
    core.tiler.animation.animate(
        window: WindowID(999),
        on: screen,
        from: CGRect(x: 0, y: 0, width: 100, height: 100),
        to: CGRect(x: 800, y: 0, width: 100, height: 100)
    )
    return core.tiler.animation.activeCount > 0
}

/// Opt-in `scroll.set_wrap_focus` (#168): with the toggle on,
/// stepping `focus` past a row end lands on the far end; `swap`
/// still never wraps.
@Suite("Scrolling wrap focus (#168)", .serialized)
@MainActor
struct ScrollingWrapFocusTests {
    @Test("Focus wraps forward past the last window")
    func wrapsForward() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 3, focus: WindowID(3))
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        // Past the last (3) lands on the first (1).
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Focus wraps backward past the first window")
    func wrapsBackward() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 3, focus: WindowID(1))
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        // Past the first (1) lands on the last (3).
        #expect(core.activeSpace?.focused == WindowID(3))
    }

    @Test("Swap never wraps, even with the toggle on")
    func swapStillStopsAtEnds() {
        let core = makeCore()
        let space = makeScrollingSpace(
            core,
            windows: 3,
            focus: WindowID(3)
        )
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        // At the last window, swapping right finds nothing to
        // trade with (a wrapping swap would teleport the window
        // across the whole row) — the order stays put.
        let right = core.execute(
            "swap",
            args: [.string("right")]
        )
        #expect(!right.isSuccess)
        #expect(
            core.state.workspaces[space]?.windows
                == [1, 2, 3].map { WindowID($0) }
        )
    }

    @Test("A single-window row does not wrap onto itself")
    func singleWindowNoSelfWrap() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 1, focus: WindowID(1))
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        // Only one window: wrapping would land on itself, so the
        // step falls through and reports no neighbor instead.
        let right = core.execute(
            "focus",
            args: [.string("right")]
        )
        #expect(!right.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Wrapping forward defers the raise (backward pan)")
    func wrapForwardDefersRaise() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 3, focus: WindowID(3))
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        // Wall the leading edge: since #878 the wall, not the
        // direction, is what defers — toward an OPEN leading
        // edge the wrapped-to window slides in from the void
        // and raises at once.
        let bounds = CGRect(
            x: 0,
            y: 0,
            width: 1920,
            height: 1080
        )
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.allScreenBounds = {
            [
                bounds,
                CGRect(
                    x: -1920,
                    y: 0,
                    width: 1920,
                    height: 1080
                ),
            ]
        }
        guard startDummyPan(core) else { return }
        // Wrap-forward to index 0 is a lower-index move — a pan
        // toward the walled leading edge (#143/#878), so the
        // raise stays pending behind the pan even though the
        // key pressed was "right".
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(1))
        #expect(core.pendingFocusRaise == WindowID(1))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Wrapping backward raises immediately (forward pan)")
    func wrapBackwardRaisesImmediately() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 3, focus: WindowID(1))
        core.execute("scroll.set_wrap_focus", args: [.bool(true)])
        guard startDummyPan(core) else { return }
        // Wrap-backward to the last index is a higher-index move —
        // a forward pan (#158), so the raise fires at once and
        // nothing stays pending, despite the "left" key.
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.activeSpace?.focused == WindowID(3))
        #expect(core.pendingFocusRaise == nil)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("With the toggle off, ends still stop")
    func offKeepsStopAtEnds() {
        let core = makeCore()
        _ = makeScrollingSpace(core, windows: 3, focus: WindowID(3))
        // Default off — no set call.
        let right = core.execute(
            "focus",
            args: [.string("right")]
        )
        #expect(!right.isSuccess)
        #expect(core.activeSpace?.focused == WindowID(3))
    }
}
