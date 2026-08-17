import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-wallraise-\(UUID().uuidString)"
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
/// dummy animation on an unmanaged window (its frames apply to
/// no element). Returns false when no display is available —
/// callers skip, matching the screen-guard convention.
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

/// Which edges defer the scrolling focus raise (#143/#878): the
/// wall, not the direction. Toward a walled edge the target
/// sits pinned on screen behind the viewport and the pan
/// reveals it, so the raise waits for the settle; toward an
/// open edge the target slides in from the void, so it raises
/// first and rides in on top. The pending-raise *machinery*
/// (supersede, echoes, settle) is `ScrollingDeferredRaiseTests`;
/// this suite pins which topology arms it.
@Suite("Scrolling wall raise policy", .serialized)
@MainActor
struct ScrollingWallRaiseTests {
    @Test("A forward focus past an OPEN trailing edge is instant")
    func forwardFocusRaisesImmediately() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(1))
        guard startDummyPan(core) else { return }
        // The trailing pile hides in the void (the factory pins
        // the single-screen verdict), so raise-first keeps the
        // target on top as it slides in (#158). Nothing stays
        // pending even mid-pan.
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(2))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Backward toward an OPEN leading edge raises at once")
    func backwardOpenLeadingRaisesImmediately() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        // No wall: the factory pins the single-screen verdict,
        // so the leading pile hangs in the void and the target
        // itself slides in — raise-first keeps the motion on
        // top and transfers keystrokes instantly (#878's
        // symmetric ruling; the wall, not the direction, is
        // what defers).
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("focus", args: [.string("left")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(4))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A forward focus into a walled trailing edge defers")
    func forwardFocusIntoWallDefers() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(1))
        // A screen beyond the right (trailing) edge (#878): the
        // trailing pile sits fully on-screen BEHIND the
        // viewport, so an immediate raise would pop the target
        // over its neighbors before the slide — the #143
        // artifact, on the forward side.
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.allScreenBounds = {
            [
                bounds,
                CGRect(x: 1920, y: 0, width: 1920, height: 1080),
            ]
        }
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == WindowID(2))
        #expect(core.activeSpace?.focused == WindowID(2))
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.pendingFocusRaise == nil)
    }

    @Test("A LEADING-side neighbor keeps forward raises instant")
    func leadingNeighborKeepsForwardImmediate() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(1))
        // The wall verdict is per EDGE: a screen beyond the
        // left (leading) edge says nothing about the trailing
        // pile, which still hides in the void — forward stays
        // raise-first.
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
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
        #expect(
            core.execute("focus", args: [.string("right")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == nil)
        #expect(core.activeSpace?.focused == WindowID(2))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Vertical: upward defers even with no screen above")
    func verticalUpwardAlwaysDefers() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(5))
        core.execute(
            "scroll.set_orientation",
            args: [.string("vertical")]
        )
        // The vertical top is macOS's OWN wall (#139): nothing
        // may sit above the top screen border, so the upward
        // pile is always on screen and upward focus always
        // defers — the factory's single-screen pin (no neighbor
        // above) must not open that edge.
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("focus", args: [.string("up")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == WindowID(4))
        #expect(core.activeSpace?.focused == WindowID(4))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Vertical: a screen below defers the downward raise")
    func verticalForwardIntoBottomWallDefers() {
        let core = makeCore()
        makeScrollingSpace(core, windows: 5, focus: WindowID(1))
        core.execute(
            "scroll.set_orientation",
            args: [.string("vertical")]
        )
        // The trailing edge follows the axis (#878): vertical
        // scrolling's trailing pile is at the BOTTOM, so only a
        // screen below walls it.
        let bounds = CGRect(x: 0, y: 0, width: 1920, height: 1080)
        core.tiler.visibleBounds = { _ in bounds }
        core.tiler.allScreenBounds = {
            [
                bounds,
                CGRect(x: 0, y: 1080, width: 1920, height: 1080),
            ]
        }
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("focus", args: [.string("down")])
                .isSuccess
        )
        #expect(core.pendingFocusRaise == WindowID(2))
        #expect(core.activeSpace?.focused == WindowID(2))
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
