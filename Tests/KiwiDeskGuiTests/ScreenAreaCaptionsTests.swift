import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A split card's area names under the card (#3697): a line per
/// top edge, a card below pushed past them, and the panes drawing
/// no area name of their own.
@Suite("Screen area captions (#3697)")
struct ScreenAreaCaptionsTests {
    private func display(_ id: UInt32, y: CGFloat = 0) -> Display {
        Display(
            id: DisplayID(id),
            name: "Wide",
            frame: CGRect(x: 0, y: y, width: 3440, height: 1440)
        )
    }

    private func whole() -> ScreenSplit {
        ScreenSplit.whole(width: 3440, height: 1440)
    }

    @Test("side by side is one line, stacked one line per area")
    func linesFollowTheTopEdges() throws {
        let side = try #require(whole().splitting(0, .sideBySide))
        #expect(
            ScreenArrangement.captionLines(of: side).map { $0.count }
                == [2]
        )
        let stacked = try #require(whole().splitting(0, .stacked))
        #expect(
            ScreenArrangement.captionLines(of: stacked).map { $0.count }
                == [1, 1]
        )
        #expect(ScreenArrangement.captionLines(of: nil).isEmpty)
        #expect(ScreenArrangement.captionReach(of: nil) == 0)
        #expect(
            ScreenArrangement.captionReach(of: stacked)
                > ScreenArrangement.captionReach(of: side)
        )
    }

    @Test("a card below a split card clears its names")
    func cardBelowClears() throws {
        let upper = display(1, y: 1440)
        let lower = display(2)
        let split = try #require(whole().splitting(0, .sideBySide))
        let layout = ScreenArrangement.layout(
            displays: [upper, lower],
            mainID: lower.id,
            canvas: CGSize(width: 600, height: 300),
            splits: [upper.fingerprint: split]
        )
        let top = try #require(
            layout.displays.first { $0.id == upper.id }
        ).rect
        let bottom = try #require(
            layout.displays.first { $0.id == lower.id }
        ).rect
        let reach = ScreenArrangement.captionReach(of: split)
        #expect(bottom.minY >= top.maxY + reach - 0.5)
        // Unsplit, the two still touch.
        let plain = ScreenArrangement.layout(
            displays: [upper, lower],
            mainID: lower.id,
            canvas: CGSize(width: 600, height: 300)
        )
        let a = try #require(plain.displays.first { $0.id == upper.id })
        let b = try #require(plain.displays.first { $0.id == lower.id })
        #expect(abs(b.rect.minY - a.rect.maxY) < 0.5)
    }

    @Test("cards side by side keep their places")
    func rowKeepsItsPlaces() throws {
        let left = display(1)
        let right = Display(
            id: DisplayID(2),
            name: "B",
            frame: CGRect(x: 3440, y: 0, width: 3440, height: 1440)
        )
        let split = try #require(whole().splitting(0, .sideBySide))
        let layout = ScreenArrangement.layout(
            displays: [left, right],
            mainID: left.id,
            canvas: CGSize(width: 600, height: 300),
            splits: [left.fingerprint: split]
        )
        let tops = layout.displays.map(\.rect.minY)
        #expect(Set(tops).count == 1)
    }

    /// The panes draw the screen's header alone; the names are the
    /// captions', mounted under each card.
    @Test("names leave the card for the captions")
    func namesLeaveTheCard() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Screens"
            )
        let read = { (name: String) throws -> String in
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(name),
                    encoding: .utf8
                )
            ).filter { !$0.isWhitespace }
        }
        let pane = try read("ScreenAreaPane.swift")
        #expect(!pane.contains("areaLabel("))
        #expect(pane.contains("Text(model.screenLabel(display))"))
        let picture = try read("ScreensPicture.swift")
        #expect(
            picture.contains(
                "ifletsplit=model.areaSplit(of:drawn.display){"
                    + "ScreenAreaCaptions("
            )
        )
        let captions = try read("ScreenAreaCaptions.swift")
        #expect(
            captions.contains(
                "ScreenArrangement.captionLines(of:split)"
            )
        )
    }
}
