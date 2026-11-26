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

    @Test("BSP: a trailing-edge drag moves the window's own split")
    func trailingDragMovesOwnSplit() throws {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        let before = try #require(frames(core)[w(1)])
        drop(core, id, w(1), .bspSplitH(100, leading: false))
        let after = try #require(frames(core)[w(1)])
        #expect(abs(after.width - before.width - 100) < 1)
        #expect(splits(core, id).horizontal.keys.sorted() == [w(1)])
        #expect(splits(core, id).vertical.isEmpty)
        #expect(core.sessionRatios(of: id).splitRatioH == nil)
    }

    @Test("BSP: a leading-edge drag moves the split before the window")
    func leadingDragMovesTheSplitBefore() throws {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 2)
        let before = try #require(frames(core)[w(2)])
        drop(core, id, w(2), .bspSplitH(100, leading: true))
        let after = try #require(frames(core)[w(2)])
        #expect(abs(after.width - before.width - 100) < 1)
        #expect(abs(after.maxX - before.maxX) < 1)
        #expect(splits(core, id).horizontal.keys.sorted() == [w(1)])
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
        #expect(splits(core, id).vertical.keys.sorted() == [w(2)])
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
        // w1 | (w2 | (w3 over w4)) at 2560 × 1440.
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
        #expect(stored.horizontal.keys.sorted() == [w(1), w(2)])
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

    @Test("BSP: a re-key carries the splits and a close ends them")
    func rekeyAndCloseReachTheSplits() {
        let (core, id) = makeSpace("bsp", windows: 2, focus: 1)
        press(core, "x", 50)
        core.rekeyBspSplits(w(1), to: w(9))
        #expect(splits(core, id).horizontal.keys.sorted() == [w(9)])
        core.forgetBspSplits(of: w(9))
        #expect(core.sessionRatios(of: id).bspSplits == nil)
    }
}
