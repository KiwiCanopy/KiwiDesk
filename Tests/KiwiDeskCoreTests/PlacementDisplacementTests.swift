import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-placement-displaced-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// The `PlacementBounceTests` fixture, per-file by convention:
/// two windows on one scrolling space, `other` focused, the
/// ledger cleared after the mode's retile.
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
    _ = core.execute(
        "set_mode",
        args: [.string(space.raw), .string("scrolling")]
    )
    core.tiler.placements = PlacementLedger()
    core.state.workspaces.focus(other, in: space)
    return (target, other)
}

/// Wholly on screen (bounds start at y = 25, end at x = 1440) at
/// the window's own size, so the edge arm cannot fire — a frame
/// at the state frame (y = 0) would straddle the top edge and
/// pass on that arm instead.
private let onscreen = CGRect(x: 800, y: 100, width: 400, height: 300)

@MainActor
private func focused(_ core: KiwiCore) -> WindowID? {
    core.activeSpace?.focused
}

/// The third scrolling discriminator (#1161, device 20:21): once
/// the emulator's size bound is learned no retile asks it
/// anything, and it still focuses itself 0.7 s after a focus
/// command moves focus OFF it. The displacement is recorded in
/// the placement ledger by the one focus command path, so it
/// shares the ledger's prune, renewal bound, forget and rekey.
@Suite("Placement bounce — the displacement (#1161)", .serialized)
@MainActor
struct PlacementDisplacementTests {
    @Test("A window a focus command moved off is distrusted")
    func displacedWindowIsDistrusted() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.tiler.placements.noteDisplaced(target, frame: onscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    @Test("A displacement past the window is honored")
    func expiredDisplacementIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.noteDisplaced(
            target,
            frame: onscreen,
            at: Date(
                timeIntervalSinceNow: -PlacementLedger.echoWindow - 0.1
            )
        )
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// The pan that follows a step re-places the window it left;
    /// the placement must not erase the displacement.
    @Test("A later placement keeps the displacement")
    func placementKeepsTheDisplacement() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        core.tiler.placements.noteDisplaced(target, frame: onscreen)
        core.tiler.placements.stamp(target, target: onscreen)
        core.handle(.windowFocused(target))
        #expect(focused(core) == other)
    }

    /// A bare size mismatch is an echo not yet landed as often
    /// as a refusal (the #1049 lesson), and discriminates nothing.
    @Test("A size mismatch alone is honored")
    func sizeMismatchAloneIsHonored() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        let asked = CGRect(x: 800, y: 100, width: 500, height: 300)
        core.tiler.placements.stamp(target, target: asked)
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    @Test("A click on the displaced window escapes")
    func clickEscapes() {
        let core = makeCore()
        let (target, _) = makeFixture(core)
        core.tiler.placements.noteDisplaced(target, frame: onscreen)
        core.lastLeftClick = (Date(), CGPoint(x: 10, y: 10), target)
        core.handle(.windowFocused(target))
        #expect(focused(core) == target)
    }

    /// The wiring: the focus command records the window it left.
    @Test("A focus command notes the window it moved off")
    func focusCommandNotesTheDisplacement() {
        let core = makeCore()
        let (target, other) = makeFixture(core)
        #expect(!core.tiler.placements.recentDisplacement(other))
        core.focusWindow(target, warp: false)
        #expect(core.tiler.placements.recentDisplacement(other))
        #expect(!core.tiler.placements.recentDisplacement(target))
    }
}
