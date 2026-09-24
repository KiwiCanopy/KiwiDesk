import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The one placement rule for the bars on the shelf (#1517): a
/// lone bar at the alignment; two as one joined plate in `order`
/// at the alignment, each section its need until the shelf is
/// full, the Space section then shrinking no further than the
/// minimum.
@Suite("Shelf arrangement")
struct ShelfArrangementTests {
    private typealias Slot = ShelfArrangement.Slot

    /// A shelf with no gutter, so each sum below reads straight.
    private func shelf(
        order: KiwiShelf.Order = .spacesFirst,
        alignment: KiwiShelf.Alignment = .center,
        minimum: CGFloat = 40,
        gap: CGFloat = 0
    ) -> KiwiShelf {
        var shelf = KiwiShelf()
        shelf.order = order
        shelf.alignment = alignment
        shelf.minimum = minimum
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

    @Test("Two that fit are one plate, each section its need")
    func bothFit() {
        let placed = arrange(300, 200, shelf())
        #expect(
            placed.space
                == Slot(offset: 250, length: 300, alignment: .end)
        )
        #expect(
            placed.app
                == Slot(offset: 550, length: 200, alignment: .start)
        )
    }

    @Test(
        "The joined plate sits at the alignment",
        arguments: [
            (KiwiShelf.Alignment.start, CGFloat(0)),
            (.center, 250),
            (.end, 500),
        ]
    )
    func joinedAtAlignment(alignment: KiwiShelf.Alignment, lead: CGFloat) {
        let placed = arrange(300, 200, shelf(alignment: alignment))
        #expect(placed.space?.offset == lead)
        #expect(placed.app?.offset == lead + 300)
    }

    @Test("Full: the Space section shrinks to the App Bar's need")
    func spaceGivesWay() {
        let placed = arrange(900, 200, shelf())
        #expect(
            placed.space
                == Slot(offset: 0, length: 800, alignment: .end)
        )
        #expect(
            placed.app
                == Slot(offset: 800, length: 200, alignment: .start)
        )
    }

    @Test("Full: never below the minimum; the App Bar takes the rest")
    func minimumHolds() {
        let placed = arrange(700, 800, shelf())
        #expect(placed.space?.length == 400)
        #expect(
            placed.app
                == Slot(offset: 400, length: 600, alignment: .start)
        )
    }

    /// The minimum is a floor on shrinking, never a length the
    /// Space Bar is padded up to.
    @Test("A Space Bar needing less than its minimum keeps its need")
    func underMinimumKeepsItsNeed() {
        let placed = arrange(100, 950, shelf())
        #expect(placed.space?.length == 100)
        #expect(
            placed.app
                == Slot(offset: 100, length: 900, alignment: .start)
        )
    }

    @Test("Apps first puts the App section first")
    func appsFirst() {
        let placed = arrange(700, 800, shelf(order: .appsFirst))
        #expect(
            placed.app
                == Slot(offset: 0, length: 600, alignment: .end)
        )
        #expect(
            placed.space
                == Slot(offset: 600, length: 400, alignment: .start)
        )
    }

    @Test("The item gap separates the two sections")
    func gutter() throws {
        let placed = arrange(700, 800, shelf(gap: 10))
        let space = try #require(placed.space)
        let app = try #require(placed.app)
        #expect(space.length == 396)
        #expect(app.offset == 406)
        #expect(app.offset + app.length == 1000)
    }

    @Test("The minimum is clamped to its range")
    func minimumClamped() {
        let placed = arrange(700, 800, shelf(minimum: 5))
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
