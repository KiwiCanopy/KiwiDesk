import AppKit
import CoreGraphics
import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A split card names its screen once, in a band across its top,
/// and lays every pane, divider and capsule out under it (#3697 ▸
/// owner, ui-designer 2026-11-27).
@Suite("Screen card band (#3697)")
@MainActor
struct ScreenCardBandTests {
    private func whole() -> ScreenSplit {
        ScreenSplit.whole(width: 3440, height: 1440)
    }

    @Test("no pane reaches into the band", arguments: [false, true])
    func panesClearTheBand(stacked: Bool) throws {
        var split = try #require(
            whole().splitting(0, stacked ? .stacked : .sideBySide)
        )
        split = try #require(split.splitting(1, .sideBySide))
        let size = CGSize(width: 300, height: 160)
        let band = CGRect(
            x: 0,
            y: 0,
            width: size.width,
            height: ScreenCard.band(split)
        )
        #expect(band.height == ScreenCardChips.headerHeight)
        let panes = ScreenCard.paneRects(of: split, in: size)
        #expect(panes.count == 3)
        for pane in panes {
            #expect(!pane.rect.intersects(band))
            #expect(pane.rect.minY >= band.maxY)
            #expect(pane.rect.maxY <= size.height + 0.5)
        }
        // A whole card has no band: its one pane carries the header.
        #expect(ScreenCard.band(nil) == 0)
        let one = ScreenCard.paneRects(of: nil, in: size)
        #expect(one.map(\.rect) == [CGRect(origin: .zero, size: size)])
    }

    /// The dividers and capsules lay out in the same area: their
    /// scale reads it, and both stand under the band.
    @Test("dividers and capsules stand under the band")
    func dividersClearTheBand() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Settings/Components/Screens/"
                            + "ScreenCard.swift"
                    ),
                encoding: .utf8
            )
        ).filter { !$0.isWhitespace }
        #expect(source.contains("dividers(stored).offset(y:Self.band(split))"))
        #expect(source.contains("ifletrect=Self.paneRects(of:split,in:size)"))
        #expect(
            source.contains(
                "letarea=Self.areaRect(of:size,split:split).size"
            )
        )
        #expect(source.contains("ScreenCardBand(model:model,display:display)"))
    }

    /// The band's name asks no more than the floor: a long name
    /// truncates in the middle rather than drop the row, so a twin
    /// keeps its position (#3697 ▸ review).
    @Test("a long name truncates rather than leave the band")
    func longNameTruncates() {
        let model = makeTestModel()
        let width = { (name: String) -> CGFloat in
            let display = Display(
                id: DisplayID(9),
                name: name,
                frame: CGRect(x: 0, y: 0, width: 1512, height: 982)
            )
            let host = NSHostingView(
                rootView: ScreenCardBand(model: model, display: display)
            )
            return host.fittingSize.width
        }
        let short = width("A")
        let long = width(String(repeating: "Integriertes Display ", count: 6))
        #expect(abs(long - short) < 1)
    }
}
