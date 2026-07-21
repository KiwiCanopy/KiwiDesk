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
