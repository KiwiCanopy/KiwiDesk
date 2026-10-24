import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// Where a bar item's list starts growing (#2571 ▸ Ruling): a plate
/// the item's size at the list's near edge, across from the item,
/// inside the list. Pure, AppKit screen coordinates (y up).
@Suite("Bar list seed geometry (#2571)")
struct BarPeekSeedTests {
    private let item = CGRect(x: 500, y: 875, width: 24, height: 18)

    @Test("A top bar's seed sits on the list's top edge under the item")
    func topSeed() {
        let list = CGRect(x: 420, y: 700, width: 180, height: 160)
        let seed = BarPeekMorph.seed(item: item, list: list, edge: .top)
        #expect(seed.size == item.size)
        #expect(seed.maxY == list.maxY)
        #expect(seed.midX == item.midX)
    }

    @Test("A bottom bar's seed sits on the list's bottom edge")
    func bottomSeed() {
        let low = CGRect(x: 500, y: 5, width: 24, height: 18)
        let list = CGRect(x: 420, y: 29, width: 180, height: 160)
        let seed = BarPeekMorph.seed(item: low, list: list, edge: .bottom)
        #expect(seed.minY == list.minY)
        #expect(seed.midX == low.midX)
    }

    @Test("A side bar's seed sits on the list's near side, level")
    func sideSeeds() {
        let side = CGRect(x: 5, y: 400, width: 20, height: 20)
        let list = CGRect(x: 31, y: 330, width: 180, height: 160)
        let left = BarPeekMorph.seed(item: side, list: list, edge: .left)
        #expect(left.minX == list.minX)
        #expect(left.midY == side.midY)
        let right = BarPeekMorph.seed(item: side, list: list, edge: .right)
        #expect(right.maxX == list.maxX)
    }

    /// A list clamped by the screen edge still holds its whole seed.
    @Test("A clamped list keeps the seed inside it")
    func clampedListHoldsTheSeed() {
        let corner = CGRect(x: 2, y: 875, width: 24, height: 18)
        let list = CGRect(x: 8, y: 700, width: 180, height: 160)
        let seed = BarPeekMorph.seed(item: corner, list: list, edge: .top)
        #expect(list.contains(seed))
        #expect(seed.minX == list.minX)
    }

    @Test("An item wider than its list is cut to the list")
    func wideItemIsCut() {
        let wide = CGRect(x: 400, y: 875, width: 300, height: 18)
        let list = CGRect(x: 450, y: 700, width: 180, height: 160)
        let seed = BarPeekMorph.seed(item: wide, list: list, edge: .top)
        #expect(seed.width == list.width)
        #expect(list.contains(seed))
    }
}
