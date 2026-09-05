import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A resize refusal names a window the write could actually
/// have resized (#1259): the own-minimum wording is owed only
/// to a focused window ON the side that could not shrink. In
/// bsp that side is geometric, so a window spanning the axis
/// belongs to neither; in stack it is a zone, which a focus
/// outside the tiled members sits outside of too.
///
/// Every assertion reads the `ResizeRefusal` STRUCTURE rather
/// than rendered text, which is why no locale is pinned (#96);
/// an assertion swapped to the sentence owes one (#740).
@Suite("Resize refusal targeting (#1259)")
@MainActor
struct ResizeRefusalTargetingTests {
    /// Pinned display (#531) and pinned gaps (#660) — the side
    /// classification and the span arithmetic divide both — plus
    /// the `min_window_size` every clamp below is measured
    /// against and the split strategy that shapes the tree.
    private func makeCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-bsp-refusal-\(UUID().uuidString)"
                )
        )
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.tiler.settings.gapsGlobal = Gaps(
            outer: Gaps.Outer(
                top: 10,
                bottom: 10,
                left: 10,
                right: 10
            ),
            inner: Gaps.Inner(horizontal: 16, vertical: 16)
        )
        #expect(core.tiler.settings.minWindowSize == 300)
        // The arrangement every case below reasons from: the
        // FIRST split is side-by-side whatever the display's
        // shape, so the dwindle head spans the whole height and
        // the vertical ratio divides only what is beside it.
        #expect(core.tiler.settings.bsp.strategy == .alternating)
        return core
    }

    /// `count` windows in one BSP space, focused on the first —
    /// the dwindle head, which spans the whole cross axis of the
    /// first split.
    private func makeBspSpace(
        _ core: KiwiCore,
        count: UInt32
    ) -> Space {
        for id in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("bsp")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        return core.state.workspaces[space]!
    }

    /// Confirms a learned app-enforced floor (#677) on the
    /// vertical axis: the same ask refused with the same larger
    /// answer twice, from two distinct asks.
    private func seedMinHeight(
        _ core: KiwiCore,
        window: WindowID,
        min: CGFloat
    ) {
        for asked in [CGFloat(200), CGFloat(240)] {
            for _ in 0..<2 {
                core.tiler.boundLearner.recordAsk(
                    window,
                    size: CGSize(width: 560, height: asked)
                )
                core.tiler.boundLearner.observe(
                    window,
                    currentSize: CGSize(width: 560, height: min),
                    settledRead: true
                )
            }
        }
    }

    @Test("A full-span window is not blamed for its neighbours")
    func fullSpanFocusBlamesTheStuckNeighbour() throws {
        // Wide display: the first split is side-by-side, so w1
        // holds the whole height and w2/w3 share the vertical
        // split on the other side. A height shrink from w1 moves
        // THAT split — w1's own height never changes — so when
        // it clamps, the window that cannot move is w2.
        let core = makeCore()
        _ = makeBspSpace(core, count: 3)
        let frames = core.tiler.calculatedFrames(state: core.state)
        let first = try #require(frames[WindowID(1)])
        let second = try #require(frames[WindowID(2)])
        #expect(first.height > second.height)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute("resize", args: [.string("y"), .number(-200)])
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1)
                )
            ]
        )
    }

    @Test("A full-span window carries no side's learned floor")
    func fullSpanWindowIsNoBindingCarrier() throws {
        // w1's learned 450 pt floor is real, and irrelevant to
        // the vertical split: nothing that ratio does can change
        // w1's height. Counting it made w1 the binding carrier
        // of its side — the pill on the trier — AND blocked the
        // write outright at a floor no window on that split has.
        // The floor is deliberately FEASIBLE against the span
        // (450 + w3's 300 fits): an infeasible pair makes the
        // cap give up unclamped, which moves the split and cues
        // nothing, so it would leave the second assertion below
        // watching a case the fix cannot change (guard-prover,
        // 2026-09-05).
        let core = makeCore()
        _ = makeBspSpace(core, count: 3)
        seedMinHeight(core, window: WindowID(1), min: 450)
        // The premise, pinned: without a landed bound this case
        // degenerates into the one above and would pass for the
        // wrong reason.
        let seeded = core.tiler.sizeBound(for: WindowID(1))
        #expect(seeded?.minHeight == 450)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute("resize", args: [.string("y"), .number(-200)])
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(2),
                    focused: WindowID(1)
                )
            ]
        )
        // And the neighbours' split MOVED: counting w1's floor
        // on this axis did not only misname the refusal, it
        // capped the write where w1's own height would have had
        // to shrink, so the press moved nothing at all.
        let frames = core.tiler.calculatedFrames(state: core.state)
        let second = try #require(frames[WindowID(2)])
        let third = try #require(frames[WindowID(3)])
        #expect(second.height < third.height)
    }

    @Test("With no split on the axis the refusal says so")
    func noSplitOnTheAxisReadsAsNoAxisHere() {
        // Two windows side by side: both hold the whole height,
        // so the vertical ratio divides nothing here. That is a
        // limit which does not exist (#1255), not one reached by
        // the focused window.
        let core = makeCore()
        _ = makeBspSpace(core, count: 2)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // A step far too small to reach any clamp: the sentence
        // is a fact about the arrangement, so it is owed on the
        // FIRST press. Gated on the clamp instead, this press
        // says nothing and the next few silently walk the ratio.
        core.execute("resize", args: [.string("y"), .number(-10)])
        #expect(refusals == [.noAxisHere(WindowID(1))])
    }

    @Test("A space that divides neither axis says nothing")
    func noSplitAtAllStandsDown() {
        // One window: the ratio divides nothing on EITHER axis,
        // so "this zone divides widths, not heights" would be
        // false about both. The press is refused wordlessly —
        // the silence #1258 owns, not a sentence that lies.
        let core = makeCore()
        let space = makeBspSpace(core, count: 1)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        for axis in ["x", "y"] {
            core.execute(
                "resize",
                args: [.string(axis), .number(-200)]
            )
        }
        #expect(refusals.isEmpty)
        // The WRITE still lands, cue or no cue: the ratio is a
        // stored per-space value that outlives the window
        // population, and the space opens its first split at
        // what the user set here (#383/#44/#458 — the empty and
        // single-window cases `SessionRatioTests` drives).
        #expect(
            core.state.workspaces[space.id]?
                .sessionRatios.splitRatioH != nil
        )
    }

    @Test("A stack focus in neither zone is not at its minimum")
    func stackFocusOutsideBothZonesNamesTheZone() {
        // The sibling writer's arm of the same rule. A
        // native-fullscreen window keeps its slot but leaves the
        // tiled derivations (#670), so the master/stack
        // partition places the focused window in NEITHER zone —
        // and a window the layout is not sizing cannot be at the
        // minimum the write ran into. The zone that binds names
        // itself instead.
        let core = makeCore()
        for id: UInt32 in 1...3 {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(id),
                        pid: pid_t(id),
                        appName: "App\(id)"
                    )
                )
            )
        }
        let space = core.state.workspaces.space(of: WindowID(1))!
        core.execute(
            "set_mode",
            args: [.string(space.raw), .string("stack")]
        )
        core.state.workspaces.focus(WindowID(1), in: space)
        core.state.apply(
            .windowFullscreenChanged(WindowID(1), isFullscreen: true)
        )
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        // Past the stack zone's own floor, so the write really
        // is truncated — a shrink the range still admits cues
        // nothing at all, in stack as anywhere else.
        core.execute("resize", args: [.string("x"), .number(-600)])
        #expect(
            refusals == [
                .neighborMinimum(
                    anchor: WindowID(3),
                    focused: WindowID(1)
                )
            ]
        )
    }

    @Test("A participating window still reads its own minimum")
    func participatingFocusKeepsTheOwnMinimumCue() {
        // The same arrangement, focused one window along: w2
        // sits IN the vertical split, so a clamped height
        // shrink really did stop at w2's own floor and the
        // own-minimum wording is the true one.
        let core = makeCore()
        let space = makeBspSpace(core, count: 3)
        core.state.workspaces.focus(WindowID(2), in: space.id)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        core.execute("resize", args: [.string("y"), .number(-200)])
        #expect(refusals == [.ownMinimum(WindowID(2))])
    }
}
