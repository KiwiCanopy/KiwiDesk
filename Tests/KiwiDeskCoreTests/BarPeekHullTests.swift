import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The peek's grace hull (#1946, owner ruling amendment 2): the item,
/// the peek, and the bridge between the item's peek-facing edge and
/// the peek's bar-facing edge — so the gap holds while the item's
/// neighbours on the bar stay outside and still swap.
@Suite("Bar hover peek hull")
struct BarPeekHullTests {
    /// A 20 pt item on a bar of `edge`, its peek 200 pt wide and
    /// opened 6 pt off the strip away from the edge, y up.
    private func layout(
        _ edge: AppBarEdge
    ) -> (item: CGRect, peek: CGRect, gap: CGPoint, neighbour: CGRect) {
        switch edge {
        case .top:
            let item = CGRect(x: 400, y: 850, width: 20, height: 20)
            let peek = CGRect(x: 310, y: 744, width: 200, height: 100)
            return (
                item, peek, CGPoint(x: 410, y: 847),
                item.offsetBy(dx: 28, dy: 0)
            )
        case .bottom:
            let item = CGRect(x: 400, y: 10, width: 20, height: 20)
            let peek = CGRect(x: 310, y: 36, width: 200, height: 100)
            return (
                item, peek, CGPoint(x: 410, y: 33),
                item.offsetBy(dx: -28, dy: 0)
            )
        case .left:
            let item = CGRect(x: 10, y: 400, width: 20, height: 20)
            let peek = CGRect(x: 36, y: 310, width: 200, height: 200)
            return (
                item, peek, CGPoint(x: 33, y: 410),
                item.offsetBy(dx: 0, dy: 28)
            )
        case .right:
            let item = CGRect(x: 1400, y: 400, width: 20, height: 20)
            let peek = CGRect(x: 1194, y: 310, width: 200, height: 200)
            return (
                item, peek, CGPoint(x: 1397, y: 410),
                item.offsetBy(dx: 0, dy: -28)
            )
        }
    }

    @Test(
        "The gap holds; the neighbours stay out",
        arguments: AppBarEdge.allCases
    )
    func gapHoldsNeighboursOut(_ edge: AppBarEdge) {
        let (item, peek, gap, neighbour) = layout(edge)
        let inside = { (point: CGPoint) in
            BarPeekHull.contains(point, item: item, peek: peek, edge: edge)
        }
        #expect(inside(CGPoint(x: item.midX, y: item.midY)), "\(edge)")
        #expect(inside(CGPoint(x: peek.midX, y: peek.midY)), "\(edge)")
        #expect(inside(gap), "\(edge): the gap")
        // Every corner of the neighbour's own rect, a hair inside it.
        let corners = [
            CGPoint(x: neighbour.minX + 0.5, y: neighbour.minY + 0.5),
            CGPoint(x: neighbour.maxX - 0.5, y: neighbour.minY + 0.5),
            CGPoint(x: neighbour.minX + 0.5, y: neighbour.maxY - 0.5),
            CGPoint(x: neighbour.maxX - 0.5, y: neighbour.maxY - 0.5),
        ]
        for corner in corners {
            #expect(!inside(corner), "\(edge): the neighbour at \(corner)")
        }
    }

    /// The bridge narrows to the item: the gap beside the item's own
    /// span, far out under the peek's overhang yet near the bar, is
    /// not the gap the pointer crosses.
    @Test("The bridge narrows to the item")
    func bridgeNarrowsToTheItem() {
        let (item, peek, _, _) = layout(.top)
        let nearBar = CGPoint(x: peek.minX + 5, y: item.minY - 0.5)
        #expect(
            !BarPeekHull.contains(nearBar, item: item, peek: peek, edge: .top)
        )
        let nearPeek = CGPoint(x: peek.minX + 15, y: peek.maxY + 0.5)
        #expect(
            BarPeekHull.contains(nearPeek, item: item, peek: peek, edge: .top)
        )
    }

    @Test("A point far from both is outside")
    func farIsOutside() {
        for edge in AppBarEdge.allCases {
            let (item, peek, _, _) = layout(edge)
            #expect(
                !BarPeekHull.contains(
                    CGPoint(x: -500, y: -500),
                    item: item,
                    peek: peek,
                    edge: edge
                ),
                "\(edge)"
            )
        }
    }
}
