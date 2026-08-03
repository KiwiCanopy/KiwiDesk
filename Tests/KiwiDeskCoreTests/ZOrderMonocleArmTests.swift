import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let core = makeTestCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-monocle-arm-\(UUID().uuidString)"
            )
    )
    core.tiler.visibleBounds = { _ in
        CGRect(x: 0, y: 25, width: 1440, height: 875)
    }
    return core
}

/// `count` windows in one monocle space, focus on `focused`.
@MainActor
private func makeMonocleSpace(
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
        args: [.string(space.raw), .string("monocle")]
    )
    core.state.workspaces.focus(WindowID(focused), in: space)
    return space
}

/// Holds the animation engine mid-flight so a scheduled restore
/// stays pending instead of firing at once. False with no
/// display — callers skip, per the screen-guard convention.
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

/// #689: the monocle restore arm keyed on
/// `zOrderRestoresInFlight == 0` as its loop guard — but since
/// #684 a sequence holds that counter until its landings verify,
/// and a monocle restore's floor contains the frontmost app's
/// key window (which a quiet raise can never clear), so the
/// drain always paid its per-window limit and the counter
/// suppressed a GENUINE second restore for ~120 ms after every
/// monocle bar click. The arm now refuses semantically, the
/// scrolling arm's shape: the restore's own closing re-assert
/// targets the focus that is already current, so
/// `previousFocused == id` refuses it by construction.
///
/// Companion to `ZOrderFocusJumpTests` (the scrolling arm).
@Suite(
    "Monocle restore arm (#689)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ZOrderMonocleArmTests {
    @Test("A monocle focus change arms a restore")
    func focusChangeArms() {
        let core = makeCore()
        _ = makeMonocleSpace(core, windows: 3, focused: 1)
        guard startDummyPan(core) else { return }
        #expect(!core.pendingZOrderRestore)
        core.focusWindow(WindowID(2), warp: false)
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    /// The #689 regression itself: a second focus change while a
    /// drain still holds the counter must arm — the old counter
    /// guard dropped it, deterministically, for the whole
    /// 50-400 ms drain (a normal double-target correction or
    /// held focus-nav lands exactly there).
    @Test("A focus change during a running restore still arms")
    func focusChangeDuringDrainStillArms() {
        let core = makeCore()
        _ = makeMonocleSpace(core, windows: 3, focused: 1)
        guard startDummyPan(core) else { return }
        core.zOrderRestoresInFlight = 1
        core.focusWindow(WindowID(3), warp: false)
        #expect(core.pendingZOrderRestore)
        core.zOrderRestoresInFlight = 0
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    /// The loop guard the counter used to provide, now semantic:
    /// the restore's closing re-assert focuses the window that
    /// is ALREADY focused, so the arm refuses it by construction
    /// — with no counter in the way of genuine restores.
    @Test("Re-focusing the focused window arms nothing")
    func reFocusSameWindowArmsNothing() {
        let core = makeCore()
        _ = makeMonocleSpace(core, windows: 3, focused: 2)
        guard startDummyPan(core) else { return }
        core.focusWindow(WindowID(2), warp: false)
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
