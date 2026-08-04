import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #674, the close path: the close-return pick can cross several
/// scrolling slots, and `focusWindow`'s own jump arm cannot see
/// it — the destroy fold already wrote the pick into
/// `space.focused`, so the anchor the jump test reads IS the
/// target. `armCloseReturnRestack` re-derives the distance from
/// the removed slot; this suite proves the arm directly because
/// its call site sits behind `eventLoop.isListed` (live AX —
/// the `TransientOverlayFocusTests` gate note). The fold's
/// `tiledSlot` fact is `CloseFocusReturnTests`' half.
///
/// Companion to `ZOrderFocusJumpTests`, split per the
/// early-split convention. Same suite shape: `.enabled(if:)` so
/// a screenless runner reports SKIP, `.serialized` for the
/// shared animation engine the dummy pan holds mid-flight.
@Suite(
    "Z-order restore on close-return jumps (#674)",
    .serialized,
    .enabled(if: NSScreen.main != nil)
)
@MainActor
struct ZOrderCloseReturnArmTests {

    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-close-arm-\(UUID().uuidString)"
                )
        )
        // Pin the display the overflow verdict is read from
        // (tests.md / #531).
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
    /// restore stays pending instead of firing at once.
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

    @Test("A multi-slot close-return arms a restore")
    func closeReturnJumpArmsRestore() {
        let core = makeCore()
        // Six auto-width slots overflow 1440 pt. The closed
        // window sat at tiled slot 4; the close-return pick is
        // window 1 (slot 0) — a four-slot jump.
        _ = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        #expect(!core.pendingZOrderRestore)
        core.armCloseReturnRestack(
            to: WindowID(1),
            fromRemovedSlot: 4
        )
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    @Test("An adjacent pick arms nothing")
    func adjacentPickArmsNothing() {
        let core = makeCore()
        _ = makeSpace(core, windows: 6, focused: 4)
        guard startDummyPan(core) else { return }
        // The successor pick: the neighbor inherits the removed
        // slot, a ±1 move — the raise is the whole change.
        core.armCloseReturnRestack(
            to: WindowID(4),
            fromRemovedSlot: 4
        )
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("A nil removed slot arms nothing")
    func nilSlotArmsNothing() {
        let core = makeCore()
        // A closed float or fullscreen member has no tiled slot:
        // no evidence of a jump, same asymmetry as
        // `scrollFocusJumpsSlots` — a spurious restack costs N
        // blocking raises and buries the float layer.
        _ = makeSpace(core, windows: 6, focused: 1)
        guard startDummyPan(core) else { return }
        core.armCloseReturnRestack(
            to: WindowID(1),
            fromRemovedSlot: nil
        )
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }
}
