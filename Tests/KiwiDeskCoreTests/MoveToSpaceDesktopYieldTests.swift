import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #446: moving a window off a space must not strand
/// system key focus on a now-offscreen (stashed) window. The
/// origin yields to the desktop only when nothing else can take
/// focus in its place — a remaining neighbor, or a follow that
/// switches straight to the target, both skip the yield. Split
/// out of `MoveToSpaceTests.swift` (issue #22) — same fixtures,
/// a distinct desktop-focus-yield concern.
@Suite("Move to virtual space desktop yield (issue #446)", .serialized)
@MainActor
struct MoveToSpaceDesktopYieldTests {
    private func makeCore() -> KiwiCore {
        makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-move-\(UUID().uuidString)"
                )
        )
    }

    private func addWindow(
        _ core: KiwiCore,
        _ raw: UInt32,
        app: String = "App"
    ) {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(raw),
                    pid: 1,
                    appName: app
                )
            )
        )
    }

    /// Issue #446 symptom 2: moving the ONLY window off a space
    /// without follow leaves nothing to refocus, so the moved
    /// (now stashed offscreen) window would keep OS key focus.
    /// The emptied origin must yield focus to the desktop.
    @Test("Emptying the space yields focus to the desktop")
    func emptyingSpaceYieldsDesktopFocus() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        #expect(core.activeSpace?.focused == WindowID(1))
        core.execute("move_to_space", args: [.string("2")])
        // Space 1 is now empty and the moved window held focus.
        #expect(yields == 1)
    }

    /// A neighbor remaining on the origin space is refocused
    /// instead — no desktop yield (#446).
    @Test("A remaining neighbor is refocused, not the desktop")
    func remainingNeighborSkipsDesktopYield() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is the focus; move it away, 1 remains.
        #expect(core.activeSpace?.focused == WindowID(2))
        core.execute("move_to_space", args: [.string("3")])
        #expect(yields == 0)
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    /// Issue #446 (review): the yield keys on system key focus
    /// (`lastFocused`), not on the emptied origin being the active
    /// space. A window that holds key focus while stashed on a
    /// NON-active space (a #414 traveler, or a secondary display's
    /// space) is still orphaned offscreen when moved again with no
    /// active-space neighbor — so it must still yield, not be
    /// suppressed because `from != activeSpace`.
    @Test("A focus-holding window off a non-active space yields")
    func nonActiveOriginStillYields() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        // Park window 1 on space 2; the move re-stamps it as the
        // system focus while active space 1 is left empty.
        core.execute("move_to_space", args: [.string("2")])
        #expect(core.state.workspaces.lastFocused == WindowID(1))
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        #expect(core.activeSpace?.focused == nil)
        // Move it again off the NON-active space 2. Still orphaned
        // offscreen with no active-space neighbor → yields anyway.
        yields = 0
        core.moveWindow(WindowID(1), to: SpaceID(3), follow: false)
        #expect(yields == 1)
    }

    /// Following the move switches to the target, so the origin
    /// never needs a yield (#446).
    @Test("Following the move does not yield to the desktop")
    func followSkipsDesktopYield() {
        let core = makeCore()
        var yields = 0
        core.desktopFocusYield = { yields += 1 }
        addWindow(core, 1)
        core.execute(
            "move_to_space_and_follow",
            args: [.string("2")]
        )
        #expect(yields == 0)
        #expect(core.state.workspaces.activeSpace == SpaceID(2))
    }

    /// Issue #446 symptom 1: the display-follow is a no-op with
    /// no per-display space assignment (single-monitor / headless)
    /// — a click never spuriously flips the active space. Here it
    /// bails at the `activeSpace(on:)` guard (the test's space is
    /// unassigned to a display), not the `display != focusedDisplay`
    /// one; the true cross-monitor collapse needs a second display
    /// (device QA). This pins the no-op outcome regardless.
    @Test("Display-follow click is a no-op on one display")
    func displayFollowNoOpSingleDisplay() {
        guard let screen = NSScreen.main else { return }
        let core = makeCore()
        addWindow(core, 1)
        let before = core.state.workspaces.activeSpace
        core.followDisplayUnderClick(
            at: CGPoint(
                x: screen.visibleFrame.midX,
                y: screen.visibleFrame.midY
            )
        )
        #expect(core.state.workspaces.activeSpace == before)
    }

    @Test("Moving to the current space re-stamps focus safely")
    func moveToSameSpaceIsSafe() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is space 1's focus; move it into space 1 again.
        #expect(core.activeSpace?.focused == WindowID(2))
        let response = core.execute(
            "move_to_space",
            args: [.string("1")]
        )
        #expect(response.isSuccess)
        // Both windows survive (nothing dropped) and 2 stays focus.
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1), WindowID(2)]
        )
        #expect(core.activeSpace?.focused == WindowID(2))
    }
}
