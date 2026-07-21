import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// #414 v2: sticky windows keep a fully-tiled slot when a
/// layout overflows into an `OverlapStack` pile.
@Suite("Overflow pile sticky exemption")
struct OverlapStackStickyTests {

    private func ids(_ raw: [UInt32]) -> [WindowID] {
        raw.map { WindowID($0) }
    }

    @Test("stickyExempt clamps a piled sticky below the boundary")
    func clampsPiledSticky() {
        let ordered = OverlapStack.stickyExempt(
            ids([1, 2, 3, 4, 5]),
            tiled: 3,
            sticky: [WindowID(5)]
        )
        // 5 takes the last tiled slot; 3 piles in its place.
        #expect(ordered == ids([1, 2, 5, 3, 4]))
    }

    @Test("stickyExempt leaves an already-tiled sticky alone")
    func tiledStickyUntouched() {
        let input = ids([1, 2, 3, 4])
        let ordered = OverlapStack.stickyExempt(
            input,
            tiled: 2,
            sticky: [WindowID(1)]
        )
        #expect(ordered == input)
    }

    @Test("stickyExempt never displaces a tiled sticky")
    func tiledStickyKeepsSlot() {
        let ordered = OverlapStack.stickyExempt(
            ids([1, 2, 3, 4]),
            tiled: 2,
            sticky: [WindowID(2), WindowID(4)]
        )
        // 4 must tile; sticky 2 keeps its slot, so non-sticky 1
        // is displaced instead.
        #expect(ordered == ids([2, 4, 1, 3]))
    }

    @Test("stickyExempt promotes what it can; surplus stays piled")
    func partialSurplus() {
        // One displaceable non-sticky slot, three piled
        // stickies: exactly one promotion (by pile order), the
        // remaining stickies stay in the pile, nothing lost.
        let ordered = OverlapStack.stickyExempt(
            ids([1, 5, 6, 7]),
            tiled: 2,
            sticky: [WindowID(5), WindowID(6), WindowID(7)]
        )
        #expect(ordered == ids([5, 6, 1, 7]))
    }

    @Test("stickyExempt with an all-sticky overload keeps count")
    func allStickyOverload() {
        let input = ids([1, 2, 3])
        let ordered = OverlapStack.stickyExempt(
            input,
            tiled: 1,
            sticky: [WindowID(1), WindowID(2), WindowID(3)]
        )
        // Nothing to displace: order unchanged, nothing lost.
        #expect(ordered == input)
    }

    @Test("stickyExempt preserves the id set")
    func preservesIDs() {
        let input = ids([9, 8, 7, 6, 5, 4])
        let ordered = OverlapStack.stickyExempt(
            input,
            tiled: 2,
            sticky: [WindowID(5), WindowID(4)]
        )
        #expect(Set(ordered) == Set(input))
        #expect(ordered.count == input.count)
        #expect(Array(ordered[..<2]) == ids([5, 4]))
    }

    @Test("overflowFrames reports the tiled slot count")
    func overflowFramesTiledCount() {
        guard
            let overflow = OverlapStack.overflowFrames(
                count: 5,
                in: CGRect(x: 0, y: 0, width: 600, height: 900),
                vertical: true,
                minSize: 300,
                gap: 10
            )
        else {
            Issue.record("Expected an overflow arrangement")
            return
        }
        #expect(overflow.rects.count == 5)
        #expect((1..<5).contains(overflow.tiled))
        // The tiled prefix keeps full min-size slots; the tail
        // shows title-bar slivers of exactly minSize height.
        for rect in overflow.rects[..<overflow.tiled] {
            #expect(rect.height >= 300)
        }
    }

    @Test("Grid keeps a sticky out of the last-cell pile")
    func gridPileExemption() {
        // Rigid 2x2 grid, 6 windows: capacity 4, tiled cells 3,
        // pile = windows 4...6 in the last cell. Sticky 6 must
        // take a full cell; non-sticky 3 piles instead.
        var params = GridParams()
        params.type = .rigid
        params.columns = 2
        params.rows = 2
        params.autoSize = false
        let context = LayoutContext(
            bounds: CGRect(
                x: 0,
                y: 0,
                width: 1600,
                height: 1200
            ),
            gaps: Gaps.uniform(0),
            minWindowSize: 100,
            sticky: [WindowID(6)],
            grid: params
        )
        let frames = GridLayout().calculateGeometry(
            for: ids([1, 2, 3, 4, 5, 6]),
            in: context
        )
        let cell = CGSize(width: 800, height: 600)
        // Sticky 6 owns a full cell.
        #expect(frames[WindowID(6)]?.size == cell)
        // Displaced 3 cascades in the last cell with the rest.
        let lastCellOrigin = CGPoint(x: 800, y: 600)
        #expect(frames[WindowID(3)]?.origin.x == lastCellOrigin.x)
        #expect(
            (frames[WindowID(3)]?.origin.y ?? 0)
                >= lastCellOrigin.y
        )
    }

    @Test("Track keeps a sticky out of the column cascade")
    func trackColumnExemption() {
        // One track (no breaks), four windows in a column too
        // short for two full slots: the tail cascades. Sticky 4
        // must take the single full slot at the column top.
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 600, height: 900),
            gaps: Gaps.uniform(0),
            minWindowSize: 300,
            sticky: [WindowID(4)]
        )
        let frames = TrackLayout().calculateGeometry(
            for: ids([1, 2, 3, 4]),
            in: context
        )
        guard let stickyFrame = frames[WindowID(4)] else {
            Issue.record("Expected a frame for the sticky")
            return
        }
        #expect(stickyFrame.minY == 0)
        #expect(stickyFrame.height >= 300)
    }

    @Test("cascadeRaiseOrder raises top frames first")
    func cascadeRaiseOrderFollowsFrames() {
        // Render order (minY) disagrees with array order — the
        // stickyExempt case: the promoted sticky (full slot at
        // the top) must raise FIRST even though it sits last in
        // the array, so the displaced sliver ends up on top of
        // it, title bar visible.
        let frames: [WindowID: CGRect] = [
            WindowID(10): CGRect(
                x: 0,
                y: 100,
                width: 50,
                height: 50
            ),
            WindowID(20): CGRect(x: 0, y: 0, width: 50, height: 50),
            WindowID(30): CGRect(
                x: 0,
                y: 50,
                width: 50,
                height: 50
            ),
        ]
        #expect(
            KiwiCore.cascadeRaiseOrder(
                ids([10, 20, 30]),
                frames: frames
            ) == ids([20, 30, 10])
        )
        // Ties (and missing frames) keep the input order.
        #expect(
            KiwiCore.cascadeRaiseOrder(
                ids([3, 1, 2]),
                frames: [:]
            ) == ids([3, 1, 2])
        )
    }

    @Test("Stack keeps a sticky out of the zone cascade")
    func stackZoneExemption() {
        // One master + a stack zone too short for 3 full
        // windows: the zone overflows and its tail cascades.
        // Sticky 4 (last in the zone) must keep a full slot.
        let context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 1200, height: 700),
            gaps: Gaps.uniform(0),
            minWindowSize: 300,
            sticky: [WindowID(4)]
        )
        let frames = StackLayout().calculateGeometry(
            for: ids([1, 2, 3, 4]),
            in: context
        )
        guard let stickyFrame = frames[WindowID(4)] else {
            Issue.record("Expected a frame for the sticky")
            return
        }
        // A fully-tiled zone slot keeps >= minWindowSize height;
        // a buried cascade entry is clamped to the min-size
        // title strip below a full slot. The sticky's slot must
        // be a full one at the zone top.
        #expect(stickyFrame.minY == 0)
        #expect(stickyFrame.height >= 300)
    }
}
