import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-tests-\(UUID().uuidString)"
        )
    return makeTestCore(configDirectory: directory)
}

/// Boots `count` windows into the active space and returns the
/// space id. Leaves the mode at its default.
@MainActor
private func makeSpace(
    _ core: KiwiCore,
    windows count: Int
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
    return core.state.workspaces.space(of: WindowID(1))!
}

@MainActor
private func setMode(
    _ core: KiwiCore,
    _ space: SpaceID,
    _ mode: String
) {
    _ = core.execute(
        "set_mode",
        args: [.string(space.raw), .string(mode)]
    )
}

/// Puts the animation engine mid-flight deterministically so a
/// scheduled restore stays pending instead of firing at once.
/// Returns false with no display (callers skip, matching the
/// screen-guard convention).
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

/// Scheduling of the deferred z-order restore for the
/// overlapping layouts (#150 scrolling edge piles, #153 stack
/// cascade): a swap/reorder must arm it *after* its retile, and
/// only when there is actually overlap to restack.
@Suite("Z-order restore scheduling", .serialized)
@MainActor
struct ZOrderScheduleTests {
    /// A raise stamp is a promise that an echo is coming, and the
    /// first echo consumes it. Since the sequence raises only what
    /// is out of place (#684), most of a pile is stamped and never
    /// raised — and an unconsumed stamp eats the user's next CLICK
    /// on that window for a whole second, because the click's
    /// focus report is read as the echo and reverted (owner QA,
    /// 2026-08-02: the click did nothing and had to be repeated).
    /// So the stamps of the windows the drain did not raise are
    /// dropped the moment it says so.
    @Test("Stamps of unraised windows are released")
    func unraisedStampsAreReleased() {
        let core = makeCore()
        let targets = [WindowID(1), WindowID(2), WindowID(3)]
        let generation = core.stampZOrderRaise(
            targets,
            excluding: nil
        )
        #expect(core.zOrderRaiseEchoes.count == 3)
        core.releaseZOrderStamps(
            of: targets,
            keeping: [WindowID(2)],
            generation: generation
        )
        // Only the raised one still awaits an echo; the other two
        // must not swallow a click that lands on them.
        #expect(
            Set(core.zOrderRaiseEchoes.keys) == [WindowID(2)]
        )
    }

    /// A drain that finishes after a NEWER sequence has stamped
    /// the same windows must release nothing: those stamps belong
    /// to the live sequence, and clearing them would leave its own
    /// raises' echoes unabsorbed — the focus slide this branch
    /// already shipped once, arriving by the back door
    /// (code review and architect review, 2026-08-02).
    @Test("A stale drain releases no stamps")
    func staleDrainReleasesNothing() {
        let core = makeCore()
        let targets = [WindowID(1), WindowID(2), WindowID(3)]
        let stale = core.stampZOrderRaise(targets, excluding: nil)
        // A newer sequence stamps the same windows.
        _ = core.stampZOrderRaise(targets, excluding: nil)
        core.releaseZOrderStamps(
            of: targets,
            keeping: [WindowID(2)],
            generation: stale
        )
        #expect(core.zOrderRaiseEchoes.count == 3)
    }

    @Test("A scrolling swap in an overflowing row arms a restore")
    func scrollingSwapSchedulesRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 5)
        setMode(core, space, "scrolling")
        core.state.workspaces.focus(WindowID(3), in: space)
        // Five auto-width slots overflow any screen: the ends
        // pin in edge piles whose stacking a swap can scramble.
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("swap", args: [.string("right")]).isSuccess
        )
        // Armed, deferred to the pan settle (not fired at once).
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    @Test("An all-visible scrolling swap arms no restore")
    func visibleScrollingSwapSkipsRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 2)
        setMode(core, space, "scrolling")
        core.state.workspaces.focus(WindowID(1), in: space)
        // Two narrow slots fit any screen — no piles overlap, so
        // a swap scrambles nothing.
        _ = core.execute(
            "scroll.set_slot_size",
            args: [.number(200)]
        )
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("swap", args: [.string("right")]).isSuccess
        )
        #expect(!core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
    }

    @Test("Stack promote arms the restore after its retile (#153)")
    func stackPromoteDefersRestore() {
        let core = makeCore()
        guard NSScreen.main != nil else { return }
        let space = makeSpace(core, windows: 4)
        setMode(core, space, "stack")
        // Settle the cascade at its layout targets so the only
        // thing that animates is the promote's own reorder.
        core.retile(animated: false)
        for (id, frame) in core.tiler.calculatedFrames(
            state: core.state
        ) {
            core.state.apply(.windowMoved(id, frame))
        }
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(core.tiler.animation.activeCount == 0)
        // Promote a stack-zone window: the reorder's retile flies
        // it into the master zone, starting animations.
        core.state.workspaces.focus(WindowID(4), in: space)
        #expect(core.execute("stack.promote", args: []).isSuccess)
        // Armed AFTER that retile: pre-#153 it fired mid-schedule
        // (before the dispatcher retile) and was consumed, so the
        // post-settle restore never ran. Now it is still pending.
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    @Test("framesCascade: piled frames true, tiled tracks false")
    func framesCascadePredicate() {
        // Side-by-side tracks: inner gaps separate them.
        #expect(
            !KiwiCore.framesCascade([
                WindowID(1): CGRect(x: 0, y: 0, width: 90, height: 200),
                WindowID(2): CGRect(x: 100, y: 0, width: 90, height: 200),
            ])
        )
        // An overflow cascade: title-bar offset overlaps.
        #expect(
            KiwiCore.framesCascade([
                WindowID(1): CGRect(x: 0, y: 0, width: 200, height: 200),
                WindowID(2): CGRect(x: 0, y: 40, width: 200, height: 200),
            ])
        )
        // A lone window never cascades.
        #expect(!KiwiCore.framesCascade([WindowID(1): .zero]))
    }

    @Test("A track swap in an overflowing track arms a restore")
    func trackSwapSchedulesRestore() {
        let core = makeCore()
        let space = makeSpace(core, windows: 8)
        // own_track seeds eight separate markers so the cap below
        // folds them all into one pile; fill-then-spill (#437, the
        // default) would pack them by display capacity instead.
        _ = core.execute(
            "track.set_new_window",
            args: [.string("own_track")]
        )
        setMode(core, space, "track")
        // Cap the space to one track: all eight windows pile into
        // it and cascade (cascade_all default), so a swap scrambles
        // the stacking. Turn off swap-skips-cascade (#172) so the
        // swap targets the in-pile neighbor instead of stepping
        // past the whole pile.
        _ = core.execute("track.set_limit", args: [.number(1)])
        _ = core.execute(
            "set_swap_skips_cascade",
            args: [.bool(false)]
        )
        core.state.workspaces.focus(WindowID(2), in: space)
        guard startDummyPan(core) else { return }
        #expect(
            core.execute("swap", args: [.string("down")]).isSuccess
        )
        #expect(core.pendingZOrderRestore)
        core.tiler.animation.cancelAll(snapToTargets: false)
        #expect(!core.pendingZOrderRestore)
    }

    @Test("rowOverflows: long row overflows, short row fits")
    func rowOverflowsPredicate() {
        let settings = TilingSettings()
        let bounds = CGRect(x: 0, y: 0, width: 1200, height: 800)
        var many = Space(
            id: "1",
            mode: .scrolling,
            windows: (1...6).map { WindowID(UInt32($0)) },
            focused: WindowID(1)
        )
        many.scrollRest = ScrollRest(offset: 0)
        let manyCtx = settings.context(
            bounds: bounds,
            space: many,
            sticky: []
        )
        #expect(
            ScrollingLayout.rowOverflows(for: many.windows, in: manyCtx)
        )
        var few = Space(
            id: "1",
            mode: .scrolling,
            windows: [WindowID(1)],
            focused: WindowID(1)
        )
        few.scrollRest = ScrollRest(offset: 0)
        let fewCtx = settings.context(
            bounds: bounds,
            space: few,
            sticky: []
        )
        #expect(
            !ScrollingLayout.rowOverflows(for: few.windows, in: fewCtx)
        )
    }
}
