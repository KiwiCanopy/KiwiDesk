import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #22: a window moved to another virtual space must
/// become that space's focused window at move time, so the
/// FIRST focus of the space raises (surfaces) it. Before the
/// fix the target space kept no focus, so `focus_space`
/// un-stashed the window frame-wise but never brought it
/// forward — the space rendered empty until a second focus.
@Suite("Move to virtual space (issue #22)", .serialized)
@MainActor
struct MoveToSpaceTests {
    private func makeCore() -> KiwiCore {
        KiwiCore(
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

    /// Polls `condition` up to a deadline so a settle that fires
    /// a little late under load does not flake the test.
    private func pollUntil(
        deadlineMS: Int,
        _ condition: () -> Bool
    ) async {
        var waited = 0
        while !condition(), waited < deadlineMS {
            try? await Task.sleep(for: .milliseconds(20))
            waited += 20
        }
    }

    @Test("Moved window becomes the target space's focus")
    func movedWindowFocusesTarget() {
        let core = makeCore()
        addWindow(core, 1)
        // A freshly created window is its space's focus.
        #expect(core.activeSpace?.id == SpaceID(1))
        #expect(core.activeSpace?.focused == WindowID(1))

        let response = core.execute(
            "move_to_space",
            args: [.string("2")]
        )
        #expect(response.isSuccess)
        // No follow: we stay on space 1 ...
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        // ... but the window now lives in space 2, as its focus.
        #expect(
            core.state.workspaces[SpaceID(2)]?.windows
                == [WindowID(1)]
        )
        #expect(
            core.state.workspaces[SpaceID(2)]?.focused
                == WindowID(1)
        )
    }

    @Test("First focus of the target lands on the moved window")
    func firstFocusSurfacesMovedWindow() {
        let core = makeCore()
        addWindow(core, 1)
        core.execute(
            "move_to_space",
            args: [.string("2")]
        )
        // A single focus is enough — no second switch (#22).
        core.execute(
            "focus_space",
            args: [.string("2")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(2))
        #expect(core.activeSpace?.focused == WindowID(1))
    }

    @Test("Follow keeps focus on the moved window")
    func followFocusesMovedWindow() {
        let core = makeCore()
        addWindow(core, 1)
        addWindow(core, 2)
        // Window 2 is the active-space focus; move+follow it.
        #expect(core.activeSpace?.focused == WindowID(2))
        core.execute(
            "move_to_space_and_follow",
            args: [.string("3")]
        )
        #expect(core.state.workspaces.activeSpace == SpaceID(3))
        #expect(core.activeSpace?.focused == WindowID(2))
        // Space 1 retains its other window and re-picks a focus.
        #expect(
            core.state.workspaces[SpaceID(1)]?.windows
                == [WindowID(1)]
        )
    }

    @Test("A space switch re-asserts the layout after settling")
    func spaceSwitchReassertsLayout() async throws {
        // Slot geometry needs a real screen (headless CI skips).
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        // Drive the observable animated apply path and let the
        // settle re-run use it too.
        core.tiler.settings.animations.onSpaceChange = true
        core.tiler.animation.isEnabled = false
        var applies: [WindowID: Int] = [:]
        core.tiler.animation.apply = { id, _, _ in
            applies[id, default: 0] += 1
        }
        addWindow(core, 1)
        core.execute(
            "move_to_space",
            args: [.string("2")]
        )
        // Count only what the focus + settle apply.
        applies = [:]
        core.execute(
            "focus_space",
            args: [.string("2")]
        )
        let onFocus = applies[WindowID(1)] ?? 0
        #expect(onFocus >= 1)
        // The settle (~300ms later) re-issues the whole layout, so
        // the apply count grows past the on-focus count without a
        // manual second focus — how a dropped frame is recovered.
        await pollUntil(deadlineMS: 2000) {
            (applies[WindowID(1)] ?? 0) > onFocus
        }
        #expect((applies[WindowID(1)] ?? 0) > onFocus)
    }

    /// Issue #11: switching into a focus-driven (Scrolling) space
    /// must not fire a second, *animated* retile on top of the
    /// instant switch — that redundant retile read the windows'
    /// stale stash-corner frames and sprang them "out of the
    /// corner". With space-change animation off the switch itself
    /// snaps instantly (the un-counted `setFrame` path), so the
    /// animated `apply` closure should fire zero times; a revert
    /// of the fix makes the focus hand-off retile and fire once.
    @Test("Scrolling space switch does not re-tile on focus")
    func scrollingSwitchNoRefocusRetile() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.tiler.settings.animations.onSpaceChange = false
        core.tiler.animation.isEnabled = false
        var animatedApplies: [WindowID: Int] = [:]
        core.tiler.animation.apply = { id, _, _ in
            animatedApplies[id, default: 0] += 1
        }
        addWindow(core, 1)
        // Park window 1 on a Scrolling space 2, stay on space 1.
        core.execute(
            "move_to_space",
            args: [.string("2")]
        )
        core.execute(
            "set_mode",
            args: [.string("2"), .string("scrolling")]
        )
        // Count only the switch into the Scrolling space.
        animatedApplies = [:]
        core.execute(
            "focus_space",
            args: [.string("2")]
        )
        #expect((animatedApplies[WindowID(1)] ?? 0) == 0)
    }

    /// Issue #11: `on_scrolling` gates the layout slide as focus
    /// moves within a Scrolling space. On → the focus retile
    /// animates (the counted `apply` closure fires); off → it
    /// snaps through the un-counted instant `setFrame` path.
    @Test("on_scrolling gates the within-space focus slide")
    func onScrollingGatesFocusSlide() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("scrolling")]
        )
        addWindow(core, 1)
        addWindow(core, 2)
        addWindow(core, 3)
        core.tiler.animation.isEnabled = false
        var animatedApplies = 0
        core.tiler.animation.apply = { _, _, _ in
            animatedApplies += 1
        }

        // On: focusing a different window slides (animates).
        core.tiler.settings.animations.onScrolling = true
        animatedApplies = 0
        core.focusWindow(WindowID(1), warp: false)
        #expect(animatedApplies >= 1)

        // Off: focusing snaps — no animated apply.
        core.tiler.settings.animations.onScrolling = false
        animatedApplies = 0
        core.focusWindow(WindowID(3), warp: false)
        #expect(animatedApplies == 0)
    }

    /// Issue #11 follow-up: `on_window_swap` gates the swap
    /// animation. On → the swap retile animates (counted apply);
    /// off → it snaps through the instant path (un-counted).
    @Test("on_window_swap gates the swap animation")
    func onWindowSwapGatesSwap() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        // Stack: master left, stack right — a reliable
        // left/right neighbor regardless of screen aspect.
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.animation.isEnabled = false
        var animatedApplies = 0
        core.tiler.animation.apply = { _, _, _ in
            animatedApplies += 1
        }

        // Off: swapping snaps — no animated apply.
        core.tiler.settings.animations.onWindowSwap = false
        animatedApplies = 0
        core.execute("swap", args: [.string("left")])
        #expect(animatedApplies == 0)

        // On: swapping back animates.
        core.tiler.settings.animations.onWindowSwap = true
        animatedApplies = 0
        core.execute("swap", args: [.string("right")])
        #expect(animatedApplies >= 1)
    }

    /// Issue #11 follow-up: `on_relayout` gates the structural
    /// reflow (a bare `retile()` — here driven by a mode switch).
    /// On → the reflow animates (counted apply); off → it snaps.
    @Test("on_relayout gates the structural reflow")
    func onRelayoutGatesReflow() {
        guard NSScreen.main != nil else { return }
        let core = makeCore()
        core.execute(
            "set_mode",
            args: [.string("1"), .string("bsp")]
        )
        addWindow(core, 1)
        addWindow(core, 2)
        core.tiler.animation.isEnabled = false
        var animatedApplies = 0
        core.tiler.animation.apply = { _, _, _ in
            animatedApplies += 1
        }

        // Off: the mode switch snaps — no animated apply.
        core.tiler.settings.animations.onRelayout = false
        animatedApplies = 0
        core.execute(
            "set_mode",
            args: [.string("1"), .string("stack")]
        )
        #expect(animatedApplies == 0)

        // On: the next mode switch animates.
        core.tiler.settings.animations.onRelayout = true
        animatedApplies = 0
        core.execute(
            "set_mode",
            args: [.string("1"), .string("grid")]
        )
        #expect(animatedApplies >= 1)
    }

    @Test("Switching away cancels and replaces the settle")
    func settleCancelsOnReswitch() {
        let core = makeCore()
        addWindow(core, 1)
        core.execute(
            "focus_space",
            args: [.string("2")]
        )
        let first = core.deferred.task(for: .spaceSettle)
        #expect(first != nil)
        core.execute(
            "focus_space",
            args: [.string("1")]
        )
        // The prior settle is cancelled AND a fresh one scheduled
        // for the new target — not merely cancelled.
        let second = core.deferred.task(for: .spaceSettle)
        #expect(first?.isCancelled == true)
        #expect(second != nil)
        #expect(second != first)
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
