import CoreGraphics
import Testing

@testable import KiwiDeskCore

/// The pocket's pinned slot on a bar's edge (#2678): at the strip's
/// outer end on its side, whole, the bars placed in the room left —
/// so the bars scroll and the pocket never moves.
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
        #expect(app.offset == 0)
        #expect(app.length == CGFloat(1000 - 50))
        #expect(placed.pocket?.offset == 950)
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
