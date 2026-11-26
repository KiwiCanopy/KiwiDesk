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
            configDirectory:
                testTemporaryDirectory
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
        #expect(core.tiler.settings.minWindowSizes == MinWindowSizes(all: 300))
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

    @Test("A full-span window moves no split and names the other axis")
    func fullSpanFocusMovesNoSplit() throws {
        // Wide display: the first split is side-by-side, so w1
        // holds the whole height and w2/w3 share the stacked split
        // on the other side. No split bounds w1's height (#3672),
        // so its height press moves nothing — not the neighbours'
        // split — and says the other axis divides it.
        let core = makeCore()
        _ = makeBspSpace(core, count: 3)
        let before = core.tiler.calculatedFrames(state: core.state)
        let first = try #require(before[WindowID(1)])
        let second = try #require(before[WindowID(2)])
        #expect(first.height > second.height)
        var refusals: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { refusals.append($0) }
        for step in [-200.0, 200.0] {
            core.execute("resize", args: [.string("y"), .number(step)])
        }
        #expect(
            refusals == [
                .nothingToDivide(WindowID(1), otherAxisDivides: true),
                .nothingToDivide(WindowID(1), otherAxisDivides: true),
            ]
        )
        core.retile()
        #expect(core.tiler.calculatedFrames(state: core.state) == before)
        let id = core.state.workspaces.space(of: WindowID(1))!
        #expect(core.sessionRatios(of: id) == SessionRatios())
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
        #expect(refusals == [.noAxisHere(WindowID(1), axis: "y")])
    }

    @Test("A space that divides neither axis names no axis")
    func noSplitAtAllNamesNoAxis() {
        // One window: the ratio divides nothing on EITHER axis,
        // so "this zone divides widths, not heights" would be
        // false about both. #1259 left it wordless and #1258
        // filled it with the sentence that does not name an
        // axis at all — whichever way that is worded, this case
        // must never take `noAxisHere`, which is the claim the
        // arrangement cannot support.
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
        #expect(
            refusals == [
                .nothingToDivide(WindowID(1), otherAxisDivides: false),
                .nothingToDivide(WindowID(1), otherAxisDivides: false),
            ]
        )
        // The WRITE still lands, cue or no cue: the ratio is a
        // stored per-space value that outlives the window
        // population, and the space opens its first split at
        // what the user set here (#383/#44/#458 — the empty and
        // single-window cases `SessionRatioTests` drives).
        #expect(
            core.sessionRatios(of: space.id).splitRatioH != nil
        )
    }

    @Test("A stack focus in neither zone is told nothing")
    func stackFocusOutsideBothZonesStandsDown() {
        // The sibling writer's arm of the same rule. A
        // native-fullscreen window keeps its slot but leaves the
        // tiled derivations (#670), so the master/stack
        // partition places the focused window in NEITHER zone —
        // and a window the layout is not sizing cannot be at the
        // minimum the write ran into.
        //
        // #1259 pinned the neighbouring zone being NAMED here,
        // as the honest reading of "not its own minimum". #1258
        // overruled that: a window in no partition is owed no
        // sentence about one. The clause that matters — never
        // `.ownMinimum` on a window whose size the write could
        // not change — is what both verdicts share, and it is
        // what this test still holds.
        //
        // Since #1298 the keyboard press never reaches this
        // writer with a full-screen focus — `resize()` refuses
        // and cues `windowIsFullscreen` first
        // (`FullscreenResizeTiledTests`) — and the mouse
        // `.masterRatio` drag hands it the DRAGGED window, which
        // cannot be. So the WRITER's arm is driven directly: the
        // guard is a construction net with no production reacher
        // — an ACTIVE home never drops its own sticky (#1301,
        // `ActiveHomeStickyMembershipTests`).
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
        let live = core.state.workspaces[space]!
        let stack = core.tiler.settings.resolvedStack(
            for: live,
            session: core.sessionRatios(of: live.id),
            flip: nil
        )
        core.writeCappedMasterRatio(
            proposed: stack.masterRatio - 600 / 1200,
            span: 1200,
            axis: "x",
            space: live,
            focused: WindowID(1),
            deltaSign: -600
        )
        #expect(refusals.isEmpty)
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
        #expect(
            refusals == [
                .ownMinimum(WindowID(2), axis: "y", appBound: false)
            ]
        )
    }
}
