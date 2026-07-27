import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// Issue #11: per-trigger animation gates for a Scrolling-space
/// focus slide, a window swap, and a structural reflow — each
/// toggle should switch its retile between the animated `apply`
/// path (counted here) and the un-counted instant `setFrame`
/// snap. Split out of `MoveToSpaceTests.swift` (issue #22) —
/// same fixtures, a distinct animation-gating concern.
@Suite(
    "Move to virtual space animation gates (issue #11)",
    .serialized
)
@MainActor
struct MoveToSpaceAnimationGateTests {
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
}
