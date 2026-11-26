import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The pure resolver every BSP ratio door takes (#3672): which split
/// a resize of a window moves, and the least length a split's rest
/// takes. Four windows alternating at 2560 × 1440 with 10-pt gaps:
/// w1 | (w2 over (w3 | w4)).
@Suite("BSP split owner (#3672)")
struct BspSplitOwnerTests {
    private let windows = (UInt32(1)...4).map(WindowID.init)

    private var context: LayoutContext {
        var context = LayoutContext(
            bounds: CGRect(x: 0, y: 0, width: 2560, height: 1440),
            gaps: .uniform(10),
            focused: nil
        )
        context.bsp.strategy = .alternating
        return context
    }

    private func owner(
        _ window: UInt32,
        horizontal: Bool,
        edge: BspLayout.SplitEdge = .either
    ) -> BspLayout.SplitOwner? {
        BspLayout.splitOwner(
            of: WindowID(window),
            horizontal: horizontal,
            edge: edge,
            windows: windows,
            in: context
        )
    }

    @Test("A press takes the window's own split, else the one above")
    func pressResolvesTheSplit() throws {
        let own = try #require(owner(3, horizontal: true))
        #expect(own.owner == WindowID(3))
        #expect(own.sign == 1)
        let behind = try #require(owner(4, horizontal: true))
        #expect(behind.owner == WindowID(3))
        #expect(behind.sign == -1)
        // w2's own split is stacked: its width is w1's split's.
        let above = try #require(owner(2, horizontal: true))
        #expect(above.owner == WindowID(1))
        #expect(above.sign == -1)
        #expect(owner(1, horizontal: false) == nil)
    }

    @Test("A drag takes the split behind the edge it moved")
    func dragResolvesTheEdge() {
        let leading = owner(3, horizontal: true, edge: .leading)
        #expect(leading?.owner == WindowID(1))
        #expect(owner(1, horizontal: true, edge: .leading) == nil)
        #expect(owner(4, horizontal: true, edge: .trailing) == nil)
    }

    @Test("A rest adds its same-axis floors and takes the larger across")
    func restAddsSameAxisFloors() throws {
        let split = try #require(owner(1, horizontal: true))
        let rest = BspLayout.restMinimum(
            of: split,
            windows: windows,
            in: context
        ) { _ in 300 }
        // w3 and w4 side by side under w2: 300 + 10 + 300.
        #expect(rest.size == 610)
    }
}
