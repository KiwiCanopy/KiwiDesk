import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A split pane writes its area's name on its own first line (#3697
/// ▸ owner, ui-designer 2026-11-27): inside the pane, never under
/// the card; no name under 28 pt; a chip row outranks the name. The
/// picture grows to fit and scrolls only sideways.
@Suite("Screen area names (#3697)")
@MainActor
struct ScreenAreaNameTests {
    private func whole() -> ScreenSplit {
        ScreenSplit.whole(width: 3440, height: 1440)
    }

    /// Where the name line draws in `pane`: past the card padding,
    /// one line tall.
    private func nameLine(in pane: CGRect) -> CGRect {
        let pad = ScreenCardChips.cardPadding
        return CGRect(
            x: pane.minX + pad,
            y: pane.minY + pad,
            width: pane.width - pad * 2,
            height: ScreenCardChips.areaNameLine
        )
    }

    @Test(
        "each area's name draws inside its pane",
        arguments: ["columns", "rows", "grid"]
    )
    func nameInsideThePane(shape: String) throws {
        var split: ScreenSplit
        switch shape {
        case "columns":
            split = try #require(whole().splitting(0, .sideBySide))
        case "rows":
            split = try #require(whole().splitting(0, .stacked))
        default:
            split = try #require(whole().splitting(0, .stacked))
            split = try #require(split.splitting(0, .sideBySide))
            split = try #require(split.splitting(1, .sideBySide))
        }
        let size = CGSize(width: 320, height: 200)
        let panes = ScreenCard.paneRects(of: split, in: size)
        #expect(panes.count == (shape == "grid" ? 4 : 2))
        for pane in panes {
            #expect(ScreenCardChips.namesArea(in: pane.rect.size))
            #expect(pane.rect.contains(nameLine(in: pane.rect)))
        }
    }

    @Test("a pane under 28 pt of text names nothing")
    func narrowPaneNamesNothing() {
        let pad = ScreenCardChips.cardPadding * 2
        let wide = CGSize(width: pad + 28, height: 120)
        let narrow = CGSize(width: pad + 27, height: 120)
        #expect(ScreenCardChips.namesArea(in: wide))
        #expect(!ScreenCardChips.namesArea(in: narrow))
    }

    @Test("a chip row outranks the name")
    func chipOutranksTheName() {
        let chip =
            ScreenCardChips.cardPadding * 2
            + ScreenCardChips.stackSpacing + ScreenCardChips.chipHeight
        let tight = CGSize(width: 200, height: chip + 4)
        #expect(!ScreenCardChips.namesArea(in: tight))
        let roomy = CGSize(
            width: 200,
            height: chip + ScreenCardChips.areaNameLine
        )
        #expect(ScreenCardChips.namesArea(in: roomy))
    }

    private func source(_ name: String) throws -> String {
        SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Screens/"
                            + name
                    ),
                encoding: .utf8
            )
        ).filter { !$0.isWhitespace }
    }

    /// The pane draws the name and reserves its line; the picture
    /// draws nothing under a card but its stand.
    @Test("the name is the pane's, never under the card")
    func nameIsThePanes() throws {
        let pane = try source("ScreenAreaPane.swift")
        #expect(pane.contains("}elseifletlabel=nameLine{"))
        #expect(
            pane.contains(
                "guardScreenCardChips.namesArea(in:size),letareaelse{"
                    + "returnnil}returnmodel.areaLabel(area,on:display)"
            )
        )
        #expect(pane.contains("header:chipHeader"))
        // The pane's label and hover keep the full name.
        #expect(
            pane.contains(
                ".accessibilityLabel(model.areaName(area,on:display))"
            )
        )
        #expect(pane.contains("?model.areaName(area,on:display)+"))
        let picture = try source("ScreensPicture.swift")
        #expect(!picture.contains("Caption"))
        #expect(!picture.contains("areaLabel"))
    }

    @Test("the picture grows rather than scroll up and down")
    func pictureGrows() throws {
        let fitted = ScreensPicture.height(holding: 0)
        #expect(ScreensPicture.height(holding: fitted + 300) > fitted + 300)
        #expect(ScreensPicture.height(holding: 10) == fitted)
        let picture = try source("ScreensPicture.swift")
        #expect(picture.contains("ScrollView(.horizontal){"))
        #expect(
            picture.contains(
                ".frame(height:width>0?height:Self.canvasHeight)"
            )
        )
        // Hidden until measured: no frame drawn at width 0.
        #expect(picture.contains(".opacity(width>0?1:0)"))
        #expect(!picture.contains(".vertical"))
    }
}
