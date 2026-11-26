import AppKit
import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// A BSP resize moves one split (#3672): the one behind the edge a
/// drag moved, or for a press the window's own split along the axis,
/// else the nearest one above it. Its ratio is stored under the
/// window that owns it, and every other split keeps its own, through
/// the real writers on `RunPushCommandTests`' desk.
extension RunPushCommandTests {
    private func frames(_ core: KiwiCore) -> [WindowID: CGRect] {
        core.tiler.calculatedFrames(state: core.state)
    }

    private func drop(
        _ core: KiwiCore,
        _ id: SpaceID,
        _ window: WindowID,
        _ adjustment: ResizeAdjustment
    ) {
        core.applyResizeAdjustment(
            adjustment,
            for: window,
            in: core.state.workspaces[id]!,
            bounds: CGRect(x: 0, y: 0, width: 1220, height: 820),
            moved: { _ in .both }
        )
        core.retile(animated: false)
    }

    private func splits(_ core: KiwiCore, _ id: SpaceID) -> BspSplitRatios {
        core.sessionRatios(of: id).bspSplits ?? BspSplitRatios()
    }

    /// A drop of `window` with `edit` applied to its slot, through
    /// the drop entry point, so `MouseResize.translate` names the
    /// edge.
    private func drag(
        _ core: KiwiCore,
        _ id: SpaceID,
        _ window: WindowID,
        _ edit: (inout CGRect) -> Void
    ) throws {
        let slot = try #require(frames(core)[window])
        var frame = slot
        edit(&frame)
        core.handleResizeEnd(
            window,
            slot: slot,
            frame: frame,
            in: core.state.workspaces[id]!
        )
        core.retile(animated: false)
    }

    @Test("BSP: a trailing-edge drag moves the window's own split")
    func trailingDragMovesOwnSplit() throws {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        let before = try #require(frames(core)[w(1)])
        try drag(core, id, w(1)) { $0.size.width += 100 }
        let after = try #require(frames(core)[w(1)])
        #expect(abs(after.width - before.width - 100) < 1)
        #expect(abs(after.minX - before.minX) < 1)
        #expect(Set(splits(core, id).horizontal.keys) == [w(1)])
        #expect(splits(core, id).vertical.isEmpty)
        #expect(core.sessionRatios(of: id).splitRatioH == nil)
    }

    @Test("BSP: a leading-edge drag moves the split before the window")
    func leadingDragMovesTheSplitBefore() throws {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 2)
        let before = try #require(frames(core)[w(2)])
        try drag(core, id, w(2)) {
            $0.origin.x -= 100
            $0.size.width += 100
        }
        let after = try #require(frames(core)[w(2)])
        #expect(abs(after.width - before.width - 100) < 1)
        #expect(abs(after.maxX - before.maxX) < 1)
        #expect(Set(splits(core, id).horizontal.keys) == [w(1)])
    }

    @Test("BSP: a leading drag keeps the trailing edge of a split owner")
    func leadingDragKeepsTheTrailingEdge() throws {
        // 2560 × 1440 alternating: w3 sits behind w1's side-by-side
        // split and owns the side-by-side one beside w4.
        let (core, id) = makeSpace(
            "bsp",
            windows: 4,
            focus: 3,
            width: 2560,
            height: 1440
        )
        let before = try #require(frames(core)[w(3)])
        try drag(core, id, w(3)) {
            $0.origin.x -= 100
            $0.size.width += 100
        }
        let after = try #require(frames(core)[w(3)])
        #expect(abs(after.width - before.width - 100) < 1)
        #expect(abs(after.maxX - before.maxX) < 1)
    }

    @Test("BSP: an outer edge no split bounds writes nothing")
    func outerEdgeWritesNothing() {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        drop(core, id, w(1), .bspSplitH(100, leading: true))
        #expect(core.sessionRatios(of: id) == SessionRatios())
    }

    @Test("BSP: a stacked drag moves the stacked split it ends at")
    func stackedDragMovesTheStackedSplit() throws {
        // w1 left; w2 above w3 in the rest.
        let (core, id) = makeSpace("bsp", windows: 3, focus: 2)
        let before = try #require(frames(core)[w(2)])
        drop(core, id, w(2), .bspSplitV(60, leading: false))
        let after = try #require(frames(core)[w(2)])
        #expect(abs(after.height - before.height - 60) < 1)
        #expect(Set(splits(core, id).vertical.keys) == [w(2)])
        #expect(splits(core, id).horizontal.isEmpty)
    }

    @Test("BSP: a drag stops where the rest keeps its floor")
    func dragStopsAtTheRestFloor() throws {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        drop(core, id, w(1), .bspSplitH(1000, leading: false))
        let rest = try #require(frames(core)[w(2)])
        #expect(abs(rest.width - 300) < 1)
    }

    @Test("BSP: a press on one split leaves every other split's ratio")
    func pressKeepsOtherSplits() throws {
        // Alternating at 2560 × 1440: w1 | (w2 over (w3 | w4)), so
        // w3's x press moves its own split.
        let (core, id) = makeSpace(
            "bsp",
            windows: 4,
            focus: 1,
            width: 2560,
            height: 1440
        )
        press(core, "x", 100)
        core.state.workspaces.focus(w(3), in: id)
        press(core, "x", 40)
        let stored = splits(core, id)
        #expect(Set(stored.horizontal.keys) == [w(1), w(3)])
        // w1's split held through w3's press.
        let w1 = try #require(frames(core)[w(1)])
        let half = (2560.0 - 20 - 10) / 2
        #expect(abs(Double(w1.width) - (half + 100)) < 1)
    }

    @Test("BSP: an explicit ratio write clears that axis's splits")
    func explicitRatioClearsSplits() {
        let (core, id) = makeSpace("bsp", windows: 3, focus: 1)
        press(core, "x", 50)
        core.state.workspaces.focus(w(2), in: id)
        press(core, "y", 50)
        #expect(!splits(core, id).horizontal.isEmpty)
        core.execute("bsp.set_ratio_h", args: [.number(0.5)])
        #expect(splits(core, id).horizontal.isEmpty)
        #expect(!splits(core, id).vertical.isEmpty)
    }

    @Test("BSP: a Space's ratio override clears that axis's splits")
    func overrideClearsSplits() {
        let (core, id) = makeSpace("bsp", windows: 3, focus: 1)
        press(core, "x", 50)
        core.state.workspaces.focus(w(2), in: id)
        press(core, "y", 50)
        core.execute(
            "bsp.set_ratio_h_override",
            args: [.string(id.raw), .number(0.5)]
        )
        #expect(splits(core, id).horizontal.isEmpty)
        #expect(!splits(core, id).vertical.isEmpty)
        core.execute(
            "bsp.set_ratio_v_override",
            args: [.string(id.raw), .number(0.5)]
        )
        #expect(core.sessionRatios(of: id).bspSplits == nil)
    }

    @Test("BSP: the re-key and end doors move and drop the splits")
    func rekeyAndForgetDoors() {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        press(core, "x", 50)
        core.rekeyBspSplits(w(1), to: w(9))
        #expect(Set(splits(core, id).horizontal.keys) == [w(9)])
        core.forgetBspSplits(of: w(9))
        #expect(core.sessionRatios(of: id).bspSplits == nil)
    }
}
