import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The one placement rule for the bars on the shelf (#1517): a
/// lone bar at the alignment, two at opposite ends in `order`,
/// each at its need, `share` deciding only when both overflow.
@Suite("Shelf arrangement")
struct ShelfArrangementTests {
    private typealias Slot = ShelfArrangement.Slot

    /// A shelf with no gutter, so each sum below reads straight.
    private func shelf(
        order: KiwiShelf.Order = .spacesFirst,
        alignment: KiwiShelf.Alignment = .center,
        share: CGFloat = 40,
        gap: CGFloat = 0
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.order = order
        shelf.alignment = alignment
        shelf.share = share
        shelf.itemGap = gap
        return shelf
    }

    private func arrange(
        _ spaceNeed: CGFloat?,
        _ appNeed: CGFloat?,
        _ shelf: KiwiShelf
    ) -> ShelfArrangement {
        ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: spaceNeed,
            appNeed: appNeed,
            shelf: shelf
        )
    }

    @Test("No bar, no slot")
    func empty() {
        #expect(arrange(nil, nil, shelf()) == ShelfArrangement())
    }

    @Test(
        "A lone bar spans the edge at the alignment",
        arguments: KiwiShelf.Alignment.allCases
    )
    func lone(alignment: KiwiShelf.Alignment) {
        let shelf = shelf(alignment: alignment)
        let whole = Slot(
            offset: 0,
            length: 1000,
            alignment: alignment
        )
        let space = arrange(300, nil, shelf)
        #expect(space == ShelfArrangement(space: whole))
        let app = arrange(nil, 2000, shelf)
        #expect(app == ShelfArrangement(app: whole))
    }

    @Test("Two that fit each take at least their need, ends hugged")
    func bothFit() {
        let placed = arrange(300, 200, shelf())
        #expect(
            placed.space
                == Slot(offset: 0, length: 400, alignment: .start)
        )
        #expect(
            placed.app
                == Slot(offset: 400, length: 600, alignment: .end)
        )
    }

    @Test("A bar that fits its need past its share keeps it")
    func needPastShareFits() {
        let placed = arrange(700, 200, shelf())
        #expect(placed.space?.length == 700)
        #expect(
            placed.app
                == Slot(offset: 700, length: 300, alignment: .end)
        )
    }

    @Test("One overflows: the other keeps its need and gives the rest")
    func oneOverflows() {
        let space = arrange(900, 200, shelf())
        #expect(space.space?.length == 800)
        #expect(
            space.app
                == Slot(offset: 800, length: 200, alignment: .end)
        )
        let app = arrange(100, 900, shelf())
        #expect(app.space?.length == 100)
        #expect(
            app.app
                == Slot(offset: 100, length: 900, alignment: .end)
        )
    }

    @Test("Both overflow: the share decides")
    func bothOverflow() {
        let placed = arrange(700, 800, shelf())
        #expect(placed.space?.length == 400)
        #expect(placed.app?.length == 600)
    }

    @Test("Apps first swaps the ends and the share's side")
    func appsFirst() {
        let placed = arrange(700, 800, shelf(order: .appsFirst))
        #expect(
            placed.app
                == Slot(offset: 0, length: 600, alignment: .start)
        )
        #expect(
            placed.space
                == Slot(offset: 600, length: 400, alignment: .end)
        )
    }

    @Test("The item gap separates the two segments")
    func gutter() throws {
        let placed = arrange(700, 800, shelf(gap: 10))
        let space = try #require(placed.space)
        let app = try #require(placed.app)
        #expect(space.length == 396)
        #expect(app.offset == 406)
        #expect(app.offset + app.length == 1000)
    }

    @Test("The share is clamped to its range")
    func shareClamped() {
        let placed = arrange(700, 800, shelf(share: 5))
        #expect(placed.space?.length == 200)
    }

    @Test("The Space Bar moves only when joining puts it elsewhere")
    func spaceBarMoves() {
        let lead = shelf(alignment: .start)
        #expect(
            ShelfArrangement.spaceBarMoves(shelf: lead) == nil
        )
        let centred = shelf(alignment: .center)
        #expect(
            ShelfArrangement.spaceBarMoves(shelf: centred) == .start
        )
        let trail = shelf(order: .appsFirst, alignment: .end)
        #expect(
            ShelfArrangement.spaceBarMoves(shelf: trail) == nil
        )
        let flipped = shelf(order: .appsFirst, alignment: .start)
        #expect(
            ShelfArrangement.spaceBarMoves(shelf: flipped) == .end
        )
    }

    @Test("A slot's rect lies along the strip's axis")
    func slotRect() {
        let strip = CGRect(x: 10, y: 20, width: 1000, height: 40)
        let slot = Slot(offset: 100, length: 300, alignment: .start)
        #expect(
            slot.rect(in: strip, horizontal: true)
                == CGRect(x: 110, y: 20, width: 300, height: 40)
        )
        let column = CGRect(x: 10, y: 20, width: 40, height: 1000)
        #expect(
            slot.rect(in: column, horizontal: false)
                == CGRect(x: 10, y: 120, width: 40, height: 300)
        )
    }
}
