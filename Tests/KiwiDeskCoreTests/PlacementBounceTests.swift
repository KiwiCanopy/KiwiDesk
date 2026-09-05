import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-placement-bounce-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// Two windows on one space, `other` focused. `target`'s state
/// frame is where the app SITS; each test says where KiwiDesk
/// put it.
@MainActor
private func makeFixture(
    _ core: KiwiCore
) -> (target: WindowID, other: WindowID) {
    for id in 1...2 {
        core.state.apply(
            .windowCreated(
                ManagedWindow(
                    id: WindowID(UInt32(id)),
                    pid: pid_t(id),
                    appName: "App\(id)",
                    frame: CGRect(
                        x: 500 * CGFloat(id - 1),
                        y: 0,
                        width: 400,
                        height: 300
                    )
                )
            )
        )
    }
    let target = WindowID(1)
    let other = WindowID(2)
    let space = core.state.workspaces.space(of: target)!
    // The measured arm is the scrolling void; `set_mode` retiles,
    // so the ledger is cleared after it — each test stamps what
    // its case needs.
    _ = core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.tiler.placements = PlacementLedger()
    core.state.workspaces.focus(other, in: space)
    return (target, other)
}

/// A frame STRADDLING the screen edge (bounds end at x = 1440) —
/// the scrolling pan's ask the Android Emulator answers with a
/// focus of its own. Straddling, not wholly outside: `contains`
/// must read it as crossing, and `intersects` would not.
private let offscreen = CGRect(x: 1200, y: 100, width: 400, height: 300)
/// A frame wholly on screen, where a window that is not there
/// yet is merely sliding — never a bounce.
private let onscreen = CGRect(x: 800, y: 100, width: 400, height: 300)

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// The placement bounce (#1161, measured 2026-09-05): an app
/// KiwiDesk placed past a screen edge clamps itself back and
/// focuses itself 0.8–1.5 s later, a report with a cmd-tab's
/// shape. The discriminator is that the window is NOT where
/// KiwiDesk put it; the ledger is `TilingEngine.placements`.
@Suite("Placement bounce distrust (#1161)", .serialized)
@MainActor
struct PlacementBounceTests {
    @Test("A clickless focus of a window not where we put it is distrusted")
    func bounceIsDistrusted() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
        // Never consumed: the app's second report is the same
        // bounce.
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    /// The active arm keys on the placement alone: the emulator
    /// complied within 9 pt of a pan into the void and bounced
    /// regardless (Run H, 2026-09-05), so a window sitting where
    /// we put it past the edge is still the bounce.
    @Test("A window sitting where we put it past the edge is still distrusted")
    func compliantOffscreenWindowIsDistrusted() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.state.apply(.windowMoved(target, offscreen))
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    /// Outside the scrolling void a clickless focus is how a user
    /// REACHES an off-screen window (monocle's park), so the
    /// placement alone is no verdict there: a window sitting where
    /// we parked it is honored.
    @Test("Outside scrolling a compliant off-screen window is honored")
    func compliantParkedWindowIsHonoredOutsideScrolling() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        let space = core.state.workspaces.space(of: target)!
        _ = core.execute(
            "set_mode",
            args: [.string(space.raw), .string("monocle")]
        )
        core.state.apply(.windowMoved(target, offscreen))
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// An ON-screen placement the window has not reached is a
    /// slide, not a bounce: a cmd-tab onto it is honored.
    @Test("An on-screen placement not yet reached is honored")
    func onscreenPlacementIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: onscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    @Test("A placement past the echo window is honored")
    func expiredPlacementIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(
            target,
            target: offscreen,
            at: Date(
                timeIntervalSinceNow:
                    -PlacementLedger.echoWindow - 1
            )
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    @Test("A click that reached the window escapes the distrust")
    func clickEscapes() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: offscreen)
        core.lastLeftClick = (
            Date(), CGPoint(x: 100, y: 100), target
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// The wiring: a retile that moves a window stamps it, so the
    /// distrust can fire for it afterwards — the instant leaf.
    @Test("A retile stamps every window it places")
    func retileStampsPlacements() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        #expect(core.tiler.placements.recent(target) == nil)
        core.retile(animated: false, force: true)
        #expect(core.tiler.placements.recent(target) != nil)
        #expect(core.tiler.placements.recent(other) != nil)
    }

    /// The ANIMATED leaf — the scrolling pan's, the one #1161
    /// measured — is stamped at `applyFrame`'s top, before the
    /// branch. Needs a screen to take that branch; without one it
    /// falls to the instant leaf, so a screenless host SKIPS.
    @Test(
        "An animated placement stamps too",
        .enabled(if: NSScreen.main != nil)
    )
    func animatedPlacementStamps() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.applyFrame(
            target,
            from: core.state.windows[target]!.frame,
            to: offscreen,
            animated: true
        )
        #expect(core.tiler.placements.recent(target) == offscreen)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The hidden arm (Run I, 2026-09-05): a Space switch parks the
    /// emulator at the stash corner, it REFUSES the corner and
    /// focuses itself, and the focus-follow flew the user back.
    /// The stash puts every window past the edge, so this arm also
    /// needs the refusal — a window that took the corner is a
    /// cmd-tab onto the Space just left, and follows.
    @Test("A refused stash's clickless focus stands the follow down")
    func refusedStashStandsTheFollowDown() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.moveWindow(target, to: SpaceID(2), follow: false)
        core.moveLatch.stamp(
            target,
            at: Date(
                timeIntervalSinceNow: -MoveIntentLatch.window - 1
            )
        )
        // The stash placed it; the app never went there.
        let corner = core.tiler.placements.recent(target)
        #expect(corner != nil)
        core.handle(.windowFocused(target))
        #expect(core.deferred.task(for: .focusFollow) == nil)
        #expect(core.state.workspaces.activeSpace == SpaceID(1))
        #expect(focused(core) == other)
    }

    @Test("A window that took the stash corner follows as a cmd-tab")
    func compliantStashFollows() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.moveWindow(target, to: SpaceID(2), follow: false)
        core.moveLatch.stamp(
            target,
            at: Date(
                timeIntervalSinceNow: -MoveIntentLatch.window - 1
            )
        )
        guard let corner = core.tiler.placements.recent(target)
        else {
            Issue.record("the stash placed nothing")
            return
        }
        core.state.apply(.windowMoved(target, corner))
        core.handle(.windowFocused(target))
        #expect(core.deferred.task(for: .focusFollow) != nil)
    }

    @Test("A gone window's placement is forgotten")
    func goneWindowForgets() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: offscreen)
        core.handle(.windowDestroyed(target, wasMinimized: false))
        #expect(core.tiler.placements.recent(target) == nil)
    }

    @Test("A re-key carries the placement to the new id")
    func rekeyFollows() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(target, target: offscreen)
        let fresh = WindowID(9)
        core.handleWindowRekeyed(old: target, new: fresh)
        #expect(core.tiler.placements.recent(target) == nil)
        #expect(core.tiler.placements.recent(fresh) != nil)
    }
}
