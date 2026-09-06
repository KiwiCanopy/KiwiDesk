import AppKit
import Foundation
import Testing

@testable import KiwiDeskCore

/// `resize` and a TILED window in native full screen (#1298).
///
/// Three layouts WROTE on such a focus: bsp's `bspFocusSign`
/// found no slot and fell back to `+1`, stack's split axis read
/// `inMaster` as `true` for a window `effectiveTiledMembers`
/// drops, and scrolling never consulted the focus at all — so a
/// press the user expected to do nothing moved the NEIGHBOURS,
/// silently, and grew the wrong window (device, 2026-09-07).
/// Two more refused, wordlessly and with the layout's sentence.
///
/// One guard in `resize()`, ahead of every path, answers all of
/// them the same way: refused, cued as `windowIsFullscreen`, no
/// store touched. Each case runs its negative control first —
/// the same press on the same fixture WRITES before the window
/// goes full screen — so a fixture that never reached the layout
/// cannot pass. The display is pinned (#531).
@Suite("Fullscreen keyboard resize on the tiled paths", .serialized)
@MainActor
struct FullscreenResizeTiledTests {
    private func makeCore() -> KiwiCore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwidesk-tests-\(UUID().uuidString)"
            )
        return makeTestCore(configDirectory: dir)
    }

    /// `count` tiled windows in `mode`; `focus` names the one
    /// focused, the last created by default. Windows spawn at
    /// the FRONT of the array (`newWindowPlacement = .first`),
    /// so the last created is stack's master.
    private func tiledSetup(
        _ core: KiwiCore,
        mode: String,
        count: Int,
        focus: WindowID? = nil
    ) -> WindowID {
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1600, height: 1000)
        }
        core.execute(
            "set_mode",
            args: [.string("1"), .string(mode)]
        )
        for index in 1...count {
            core.state.apply(
                .windowCreated(
                    ManagedWindow(
                        id: WindowID(UInt32(index)),
                        pid: 1,
                        appName: "A"
                    )
                )
            )
        }
        let focused = focus ?? WindowID(UInt32(count))
        core.state.apply(.windowFocused(focused))
        core.tiler.animation.isEnabled = false
        core.retile()
        return focused
    }

    /// The stores a resize path can write, read together.
    private struct Stores: Equatable {
        var ratios: SessionRatios
        var stackWeights: [WindowID: Double]
        var trackWeights: [WindowID: Double]

        @MainActor
        init(_ core: KiwiCore) {
            let space = core.state.workspaces[SpaceID("1")]
            ratios = space?.sessionRatios ?? SessionRatios()
            stackWeights = space?.stackWeights ?? [:]
            trackWeights = space?.trackWeights ?? [:]
        }
    }

    /// The control writes; the full-screen press refuses, cues
    /// the one case and leaves every store where the control
    /// put it.
    private func expectRefused(
        mode: String,
        axis: String,
        count: Int,
        focus: WindowID? = nil
    ) {
        let core = makeCore()
        let focused = tiledSetup(
            core,
            mode: mode,
            count: count,
            focus: focus
        )
        let untouched = Stores(core)
        let control = core.execute(
            "resize",
            args: [.string(axis), .number(100)]
        )
        #expect(control.isSuccess, "\(mode) \(axis): control")
        let written = Stores(core)
        #expect(
            written != untouched,
            "\(mode) \(axis): the control wrote nothing"
        )

        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        core.state.apply(
            .windowFullscreenChanged(focused, isFullscreen: true)
        )
        // The refused press SHRINKS. Scrolling measures a focus
        // the engine draws no frame for from the STORE, and a
        // second grow from the store the control just raised can
        // stop at the slot domain's own epsilon and write nothing
        // with the guard gone — a shrink from it always writes,
        // so the store assertion below is live on every path
        // (guard-prover, 2026-09-07).
        let response = core.execute(
            "resize",
            args: [.string(axis), .number(-100)]
        )
        #expect(!response.isSuccess, "\(mode) \(axis)")
        #expect(
            response.error == "the focused window is fullscreen",
            "\(mode) \(axis)"
        )
        #expect(
            cues == [.windowIsFullscreen(focused)],
            "\(mode) \(axis)"
        )
        #expect(Stores(core) == written, "\(mode) \(axis)")
    }

    /// The device case: the shared split ratio moved and the
    /// NEIGHBOUR grew, on a press aimed at the full-screen
    /// window. Both axes, since each has its own ratio.
    @Test("bsp writes no split ratio for a full-screen focus")
    func bspRefusesBothAxes() {
        expectRefused(mode: "bsp", axis: "x", count: 2)
        expectRefused(mode: "bsp", axis: "y", count: 2)
    }

    /// The split axis (x, for the default right-hand stack zone)
    /// used to fall back to "in master" and write the master
    /// ratio; the weight axis (y) refused with the layout's
    /// sentence. Three windows and a STACK-zone focus, so the
    /// weight control has a column of two to divide.
    @Test("stack writes neither ratio nor weight")
    func stackRefusesBothAxes() {
        expectRefused(mode: "stack", axis: "x", count: 2)
        expectRefused(
            mode: "stack",
            axis: "y",
            count: 3,
            focus: WindowID(1)
        )
    }

    /// Scrolling never read the focus: the slot size is the
    /// row's, and a press on a full-screen focus wrote it.
    @Test("scrolling writes no slot size")
    func scrollingRefuses() {
        expectRefused(mode: "scrolling", axis: "x", count: 2)
    }

    /// Track refused already, wordlessly and as "no focused
    /// tiled window"; the along axis (y, for the default
    /// vertical tracks) writes the share weight in the control.
    @Test("track refuses with the window's sentence, cued")
    func trackRefuses() {
        expectRefused(mode: "track", axis: "y", count: 2)
    }

    /// The MOUSE entry to the same writers: a drop that reads
    /// as a resize reaches `handleResizeEnd` only for a window
    /// `calculatedFrames` placed, which a full-screen one is
    /// not — so the drag pipeline's slot gate is what keeps a
    /// full-screen window's drop out of the store, and a
    /// relaxation of it re-opens this defect on the mouse side.
    /// The control drop writes the ratio; the same drop after
    /// the flip writes nothing.
    @Test("a full-screen window's drop moves no store")
    func dropOfFullscreenWindowWritesNothing() throws {
        let core = makeCore()
        let focused = tiledSetup(core, mode: "bsp", count: 2)
        let slots = core.tiler.calculatedFrames(state: core.state)
        let slot = try #require(slots[focused])
        let other = try #require(slots[WindowID(1)])
        // Widen the edge shared with the neighbour by 200 pt;
        // an outer edge would snap back rather than resize.
        var frame = slot
        if slot.maxX <= other.minX {
            frame.size.width += 200
        } else {
            frame.origin.x -= 200
            frame.size.width += 200
        }
        // Pinned away from every slot: no swap target, and no
        // other display for the relocate arm to find.
        core.drag.cursorLocation = {
            GeometryUtils.axPoint(CGPoint(x: -9000, y: -9000))
        }
        let untouched = Stores(core)
        core.handleDragEnd(focused, start: slot, frame: frame)
        let written = Stores(core)
        #expect(written.ratios.splitRatioH != nil)
        #expect(written != untouched)

        core.state.apply(
            .windowFullscreenChanged(focused, isFullscreen: true)
        )
        core.handleDragEnd(focused, start: slot, frame: frame)
        #expect(Stores(core) == written)
    }

    /// The layouts with no resize at all cue the window's case
    /// rather than the layout's when the focus is full screen:
    /// it is the window, not the layout, that refuses (#1298).
    @Test("monocle cues the window, not the layout")
    func monocleCuesTheWindow() {
        let core = makeCore()
        let focused = tiledSetup(core, mode: "monocle", count: 2)
        var cues: [ResizeRefusal] = []
        core.borders.onResizeRefusal = { cues.append($0) }
        // Control: not full screen, the layout refuses.
        #expect(
            !core.execute(
                "resize",
                args: [.string("x"), .number(100)]
            ).isSuccess
        )
        #expect(cues == [.layoutHasNoResize(focused)])

        cues = []
        core.state.apply(
            .windowFullscreenChanged(focused, isFullscreen: true)
        )
        let response = core.execute(
            "resize",
            args: [.string("x"), .number(100)]
        )
        #expect(
            response.error == "the focused window is fullscreen"
        )
        #expect(cues == [.windowIsFullscreen(focused)])
    }
}
