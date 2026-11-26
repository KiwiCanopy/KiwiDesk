import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pocket's pinned slot on a bar's edge (#2678): at the strip's
/// outer end on its side, whole, the bars aligned against the whole
/// edge and bounded by the slot (#3685) — so the bars scroll and the
/// pocket never moves.
@Suite("Pocket arrangement (#2678)")
struct PocketArrangementTests {
    private var shelf: KiwiShelf {
        var shelf = KiwiShelf()
        shelf.itemGap = 6
        return shelf
    }

    private func arrange(
        space: CGFloat? = 200,
        app: CGFloat? = 300,
        pocket: ShelfArrangement.PocketAsk?
    ) -> ShelfArrangement {
        ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: space,
            appNeed: app,
            spaceFloor: 40,
            shelf: shelf,
            pocket: pocket
        )
    }

    @Test("no pocket places the bars as before")
    func noPocketIsUnchanged() {
        let plain = ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: 200,
            appNeed: 300,
            spaceFloor: 40,
            shelf: shelf,
            pocket: nil
        )
        #expect(arrange(pocket: nil) == plain)
        #expect(plain.pocket == nil)
    }

    @Test("leaning to the end, it takes the strip's last stretch")
    func endPinned() throws {
        let placed = arrange(pocket: .init(need: 50, leadsEnd: true))
        let pocket = try #require(placed.pocket)
        #expect(pocket.offset == 950)
        #expect(pocket.length == 50)
        let app = try #require(placed.app)
        #expect(app.offset + app.length <= 1000 - 50)
    }

    @Test("leaning to the start, the bars move past it")
    func startPinned() throws {
        var start = shelf
        start.alignment = .start
        let placed = ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: 200,
            appNeed: 300,
            spaceFloor: 40,
            shelf: start,
            pocket: .init(need: 50, leadsEnd: false)
        )
        let pocket = try #require(placed.pocket)
        #expect(pocket.offset == 0)
        let first = min(
            try #require(placed.space).offset,
            try #require(placed.app).offset
        )
        #expect(abs(first - 50) < 0.001)
    }

    @Test("a full shelf keeps the pocket whole where it was")
    func overflowKeepsThePocket() throws {
        let roomy = arrange(pocket: .init(need: 50, leadsEnd: true))
        let full = arrange(
            space: 600,
            app: 900,
            pocket: .init(need: 50, leadsEnd: true)
        )
        #expect(full.pocket == roomy.pocket)
        let app = try #require(full.app)
        #expect(app.offset + app.length <= 1000 - 50)
        #expect(full.divider != nil)
    }

    @Test("a lone bar shares the edge with the pocket")
    func loneBar() throws {
        let placed = arrange(
            space: nil,
            pocket: .init(need: 50, leadsEnd: true)
        )
        let app = try #require(placed.app)
        #expect(app.offset + app.length <= 1000 - 50)
        #expect(placed.pocket?.offset == 950)
    }

    /// The middle of what a slot draws for a run `need` long.
    private func drawnMiddle(
        _ slot: ShelfArrangement.Slot?,
        _ need: CGFloat
    ) throws -> CGFloat {
        let drawn = try #require(slot).drawing(need)
        return drawn.offset + drawn.length / 2
    }

    @Test(
        "a centred lone bar centres on the edge, the pocket aside",
        arguments: [true, false]
    )
    func centredBarIgnoresThePocket(leadsEnd: Bool) throws {
        let placed = arrange(
            app: nil,
            pocket: .init(need: 50, leadsEnd: leadsEnd)
        )
        #expect(abs(try drawnMiddle(placed.space, 200) - 500) < 0.001)
        let space = try #require(placed.space)
        let pocket = try #require(placed.pocket)
        #expect(
            leadsEnd
                ? space.offset + space.length <= pocket.offset
                : space.offset >= pocket.offset + pocket.length
        )
    }

    @Test("a centred pair centres on the edge, the pocket aside")
    func centredPairIgnoresThePocket() throws {
        let placed = arrange(pocket: .init(need: 50, leadsEnd: true))
        let space = try #require(placed.space)
        let app = try #require(placed.app)
        let middle = (space.offset + app.offset + app.length) / 2
        #expect(abs(middle - 500) < 0.001)
    }

    @Test(
        "a lone bar at an end keeps all the room beside the pocket",
        arguments: [
            (KiwiShelf.Alignment.start, true),
            (.start, false),
            (.end, true),
            (.end, false),
        ]
    )
    func endAlignedLoneBarKeepsTheRoom(
        alignment: KiwiShelf.Alignment,
        leadsEnd: Bool
    ) throws {
        var aligned = shelf
        aligned.alignment = alignment
        let placed = ShelfArrangement.arrange(
            length: 1000,
            spaceNeed: 200,
            appNeed: nil,
            spaceFloor: 40,
            shelf: aligned,
            pocket: .init(need: 50, leadsEnd: leadsEnd)
        )
        let space = try #require(placed.space)
        #expect(space.offset == (leadsEnd ? 0 : 50))
        #expect(space.length == 950)
        #expect(space.alignment == alignment)
    }

    @Test("a centred lone bar's slot moves with no need")
    func centredSlotIsFixed() throws {
        let short = arrange(
            space: 120,
            app: nil,
            pocket: .init(need: 43.19, leadsEnd: false)
        )
        let long = arrange(
            space: 860,
            app: nil,
            pocket: .init(need: 43.19, leadsEnd: false)
        )
        #expect(short.space == long.space)
        let slot = try #require(long.space)
        #expect(slot.length >= 860)
    }

    @Test("a run too long to centre stops at the pocket's slot")
    func crowdedRunStopsAtThePocket() throws {
        let placed = arrange(
            space: 920,
            app: nil,
            pocket: .init(need: 50, leadsEnd: true)
        )
        let drawn = try #require(placed.space).drawing(920)
        #expect(abs(drawn.offset + drawn.length - 950) < 0.001)
        #expect(drawn.length == 920)
    }

    @Test("50 % and above lean to the end")
    func leaningReadsPosition() {
        var shelf = KiwiShelf()
        shelf.pocketPosition = 49.9
        #expect(!shelf.pocketLeansEnd)
        shelf.pocketPosition = 50
        #expect(shelf.pocketLeansEnd)
    }
}
