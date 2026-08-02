import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #674: the scrolling edge-pile restore was armed only by swaps,
/// window drags and native space switches — never by a plain
/// focus change or an App Bar drop. A ±1 focus step masked the
/// gap (the lone target raise is the whole visible change), but
/// an App Bar item carries an absolute `WindowID`, so a click can
/// jump several slots and leave every window between the two
/// stacked for the previous focus.
///
/// Companion to `ZOrderScheduleTests`, which covers the swap arm
/// sites; split per the early-split convention rather than grown.
@Suite("Z-order restore on focus jumps (#674)", .serialized)
@MainActor
struct ZOrderFocusJumpTests {

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-zorder-jump-\(UUID().uuidString)"
                )
        )
        // Pin the display the overflow verdict is read from
        // (tests.md / #531): whether a row overflows IS the gate
        // under test, so it must not be the host's screen.
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 25, width: 1440, height: 875)
        }
        return core
    }

    /// `count` windows in one scrolling space, focus on `focused`.
    private func makeSpace(
        _ core: KiwiCore,
        windows count: Int,
        focused: UInt32
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
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("scrolling")]
        )
        core.state.workspaces.focus(WindowID(focused), in: space)
        return space
    }

    /// Holds the animation engine mid-flight so a scheduled
    /// restore stays pending instead of firing at once. False
    /// with no display — callers skip, per the screen-guard
    /// convention.
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

    // MARK: - The focus jump

    @Test("A focus jump in an overflowing row arms a restore")
    func focusJumpSchedulesRestore() {
        let core = makeCore()
        // Six auto-width slots overflow 1440 pt: both ends pin in
        // edge piles whose stacking a multi-slot jump staled.
        _ = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        #expect(!core.pendingZOrderRestore)
        core.focusWindow(WindowID(5), warp: false)
        // Armed, and deferred to the pan settle — not consumed
        // mid-retile off the pre-jump frames (#153).
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    /// The gate arm: an all-visible row has no piles, so nothing
    /// overlaps and a jump scrambles no stacking.
    @Test("A focus jump in an all-visible row arms nothing")
    func visibleRowJumpSkipsRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 2, focused: 1)
        _ = core.execute(
            "scroll.set_slot_size",
            args: [.number(200)]
        )
        #expect(core.state.workspaces[space] != nil)
        guard startDummyPan(core) else { return }
        core.focusWindow(WindowID(2), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// A restore's own closing re-assert calls `focusWindow`
    /// (`raiseSequentially(thenFocus:)`) while the in-flight
    /// counter is still held, so arming there would re-arm the
    /// restore that is running — the monocle guard's loop, on
    /// the scrolling path. The counter must gate it.
    @Test("A focus during a restore does not re-arm it")
    func inFlightRestoreDoesNotReArm() {
        let core = makeCore()
        _ = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        core.zOrderRestoresInFlight = 1
        core.focusWindow(WindowID(5), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.zOrderRestoresInFlight = 0
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    // MARK: - The bar drop

    @Test("A bar-item drop in an overflowing row arms a restore")
    func barDropSchedulesRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        #expect(!core.pendingZOrderRestore)
        core.moveBarItem(space: space, from: 0, to: 4)
        #expect(
            core.state.workspaces[space]?.windows.first
                == WindowID(2)
        )
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    /// The gate arm again, on the drop path: a row that fits
    /// reorders without scrambling any stacking.
    @Test("A bar-item drop in an all-visible row arms nothing")
    func visibleRowDropSkipsRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 2, focused: 1)
        _ = core.execute(
            "scroll.set_slot_size",
            args: [.number(200)]
        )
        guard startDummyPan(core) else { return }
        core.moveBarItem(space: space, from: 0, to: 1)
        #expect(
            core.state.workspaces[space]?.windows.first
                == WindowID(2)
        )
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
