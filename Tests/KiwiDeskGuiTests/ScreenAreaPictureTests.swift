import CoreGraphics
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A split screen in the Screens picture (#3517 rulings 25–29): the
/// per-area scale floor, the stands, the tray under the first area,
/// the drag capsule's words and who gives way in Adjust….
@Suite("Screen area picture")
struct ScreenAreaPictureTests {
    private func display(
        _ id: UInt32,
        y: CGFloat = 0,
        width: CGFloat = 3440,
        height: CGFloat = 1440
    ) -> Display {
        Display(
            id: DisplayID(id),
            name: "Wide",
            frame: CGRect(x: 0, y: y, width: width, height: height)
        )
    }

    private func three() throws -> ScreenSplit {
        try #require(
            ScreenSplit.whole(width: 3440, height: 1440)
                .splitting(0, .sideBySide)?.splitting(1, .sideBySide)
        )
    }

    @Test func unitAreasTileTheSquare() throws {
        let units = ScreenArrangement.unitAreas(of: try three())
        #expect(units.map(\.id) == [0, 1, 2])
        #expect(units.map(\.rect.width) == [0.5, 0.25, 0.25])
        #expect(units.allSatisfy { $0.rect.height == 1 })
        #expect(ScreenArrangement.unitAreas(of: nil).count == 1)
    }

    /// Every pane holds the floor's one chip: the narrowest area,
    /// not the card, is what the scale floors on.
    @Test func everyPaneHoldsTheMinimumCard() throws {
        let screen = display(1)
        let split = try three()
        let layout = ScreenArrangement.layout(
            displays: [screen],
            mainID: screen.id,
            canvas: CGSize(width: 200, height: 120),
            splits: [screen.fingerprint: split]
        )
        let card = try #require(layout.displays.first).rect
        for unit in ScreenArrangement.unitAreas(of: split) {
            let pane = ScreenArrangement.paneRect(unit.rect, in: card.size)
            let minimum = ScreenArrangement.minimumCard
            #expect(pane.width >= minimum.width - 1)
            #expect(pane.height >= minimum.height - 1)
        }
        let whole = ScreenArrangement.layout(
            displays: [screen],
            mainID: screen.id,
            canvas: CGSize(width: 200, height: 120)
        )
        #expect(
            try #require(whole.displays.first).rect.width < card.width
        )
    }

    /// Ruling 28: a screen above another draws no stand.
    @Test func onlyTheLowestCardStands() {
        let lower = Display(
            id: DisplayID(1),
            name: "Laptop",
            frame: CGRect(x: 964, y: 0, width: 1512, height: 982)
        )
        let upper = display(2, y: 982)
        let layout = ScreenArrangement.layout(
            displays: [lower, upper],
            mainID: lower.id,
            canvas: CGSize(width: 600, height: 300)
        )
        #expect(ScreenArrangement.standing(layout) == [lower.id])
        let beside = display(3, width: 1512, height: 982)
        let side = Display(
            id: DisplayID(4),
            name: "B",
            frame: CGRect(x: 1512, y: 0, width: 1512, height: 982)
        )
        let row = ScreenArrangement.layout(
            displays: [beside, side],
            mainID: beside.id,
            canvas: CGSize(width: 600, height: 300)
        )
        #expect(
            ScreenArrangement.standing(row) == [beside.id, side.id]
        )
    }

    /// Ruling 29: the follows-main tray hangs under the first area.
    @Test func trayHangsUnderTheFirstArea() throws {
        let screen = display(1)
        let split = try three()
        let layout = ScreenArrangement.layout(
            displays: [screen],
            mainID: screen.id,
            canvas: CGSize(width: 700, height: 240),
            trayChips: 1,
            splits: [screen.fingerprint: split]
        )
        let card = try #require(layout.displays.first).rect
        let tray = try #require(layout.tray)
        #expect(tray.midX < card.midX)
        #expect(abs(tray.midX - (card.minX + card.width / 4)) < 1)
    }

    @MainActor @Test func capsuleNamesTheSnappedFraction() {
        LocalizationManager.shared.select("en")
        #expect(
            AreaSizeCapsule.label(
                length: 1147,
                snap: .fraction(1, 3),
                total: 3440
            ) == "1147 pt · ⅓"
        )
        #expect(
            AreaSizeCapsule.label(
                length: 2293,
                snap: .fraction(1, 3),
                total: 3440
            ) == "2293 pt"
        )
        #expect(
            AreaSizeCapsule.label(length: 900, snap: nil, total: 3440)
                == "900 pt"
        )
    }

    /// Ruling 26: the last area not yet typed, reading from the end,
    /// never the focused one; then the one typed longest ago.
    @Test func whoGivesWay() {
        let order = [0, 1, 2]
        #expect(AreaGiveWay.pick(order: order, typed: [], excluding: 2) == 1)
        #expect(
            AreaGiveWay.pick(order: order, typed: [2], excluding: 1)
                == 0
        )
        #expect(
            AreaGiveWay.pick(order: order, typed: [], excluding: nil)
                == 2
        )
        #expect(
            AreaGiveWay.pick(order: order, typed: [1, 0, 2], excluding: 1)
                == 0
        )
        #expect(
            AreaGiveWay.pick(
                order: [0, 1],
                typed: [0, 1],
                excluding: 0
            ) == 1
        )
        #expect(AreaGiveWay.typing(1, after: [1, 0]) == [0, 1])
    }
}
