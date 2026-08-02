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
/// `.enabled(if:)`, not an in-test `guard`: `startDummyPan` needs
/// a real `NSScreen`, and a screenless runner must report a SKIP
/// rather than five green tests that asserted nothing.
@Suite(
    "Z-order restore on focus jumps (#674)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
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

    /// A ±1 step needs no restack: the target raise is the whole
    /// visible change. Arming it anyway would put a full pile
    /// re-raise — which buries the float layer until the next
    /// genuine focus event — on every scrolling focus step.
    @Test("A single-slot step in the same row arms nothing")
    func singleSlotStepSkipsRestore() {
        let core = makeCore()
        _ = makeSpace(core, windows: 6, focused: 3)
        guard startDummyPan(core) else { return }
        core.focusWindow(WindowID(4), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The gate arm: an all-visible row has no piles, so nothing
    /// overlaps and even a jump scrambles no stacking.
    @Test("A focus jump in an all-visible row arms nothing")
    func visibleRowJumpSkipsRestore() {
        let core = makeCore()
        _ = makeSpace(core, windows: 3, focused: 1)
        // 3 × 200 pt plus gaps fits the pinned 1440 pt viewport
        // with room to spare, so the row cannot pile — while
        // 1 → 3 is still a jump, keeping this test about the
        // overflow gate alone.
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(200)]
            ).isSuccess
        )
        guard startDummyPan(core) else { return }
        core.focusWindow(WindowID(3), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The loop guard, and the reason the scrolling arm needs no
    /// in-flight counter: a restore's own closing re-assert
    /// (`raiseSequentially(thenFocus:)`) focuses the window that
    /// is ALREADY focused, so the jump distance is zero and the
    /// arm refuses it by construction.
    @Test("Re-focusing the focused window arms nothing")
    func reFocusingTheSameWindowArmsNothing() {
        let core = makeCore()
        _ = makeSpace(core, windows: 6, focused: 3)
        guard startDummyPan(core) else { return }
        core.focusWindow(WindowID(3), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// And the reason it must not borrow monocle's counter
    /// anyway: a pile drain runs on the AX queue for as long as
    /// the slowest app takes to answer, and a user stepping back
    /// and forth across the row lands inside that window
    /// constantly. Gating on the counter dropped every second
    /// jump's restack (owner device QA, 2026-08-02).
    @Test("A jump during a running restore still arms one")
    func jumpDuringRestoreStillArms() {
        let core = makeCore()
        _ = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        core.zOrderRestoresInFlight = 1
        core.focusWindow(WindowID(5), warp: false)
        #expect(core.pendingZOrderRestore)
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
        #expect(
            core.execute(
                "scroll.set_slot_size",
                args: [.number(200)]
            ).isSuccess
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

    /// The whole restore path reads `activeSpace`, so a drop on
    /// another display's bar must not arm it: it would restack a
    /// space the user is not in and leave the dropped row stale
    /// either way.
    @Test("A drop on an inactive space's bar arms nothing")
    func inactiveSpaceDropSkipsRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 6, focused: 1)
        // The ACTIVE space must itself be a scrolling row that
        // overflows, or the mode/overflow gate inside the
        // schedule call answers first and this test proves that
        // gate instead of the active-space guard it names.
        core.state.workspaces.ensureSpace("2")
        core.state.workspaces.activate("2")
        for id in 7...12 {
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
        #expect(
            core.execute(
                "set_mode",
                args: [.string("2"), .string("scrolling")]
            ).isSuccess
        )
        core.state.workspaces.focus(WindowID(7), in: "2")
        #expect(core.state.workspaces["2"]?.windows.count == 6)
        guard startDummyPan(core) else { return }
        core.moveBarItem(space: space, from: 0, to: 4)
        // The reorder itself still lands — only the restack is
        // withheld.
        #expect(
            core.state.workspaces[space]?.windows.first
                == WindowID(2)
        )
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
