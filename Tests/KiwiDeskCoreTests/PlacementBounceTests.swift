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
    core.state.workspaces.focus(other, in: space)
    return (target, other)
}

/// A frame past the screen edge — the scrolling pan's ask that
/// the Android Emulator answers by clamping itself back.
private let offscreen = CGRect(x: 1600, y: 0, width: 400, height: 300)

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

    /// The trade's edge: a window sitting where KiwiDesk put it
    /// is compliant, and its clickless refocus is the user's.
    @Test("A window where KiwiDesk put it is honored")
    func compliantWindowIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.stamp(
            target,
            target: core.state.windows[target]!.frame
        )
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
    /// distrust can fire for it afterwards.
    @Test("A retile stamps every window it places")
    func retileStampsPlacements() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        #expect(core.tiler.placements.recent(target) == nil)
        core.retile(animated: false, force: true)
        #expect(core.tiler.placements.recent(target) != nil)
        #expect(core.tiler.placements.recent(other) != nil)
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
