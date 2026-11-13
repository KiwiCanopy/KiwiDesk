import AppKit
import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Maximize card's pop-ups fit their columns in every shipped
/// catalog (#3255). A menu pop-up draws at its widest item, so the
/// widths are measured from the real row cells, hosted per catalog,
/// never restated here: a translation that grows is what reds this.
///
/// It holds three things: a column is never narrower than any of its
/// cells (`MaximizeColumns.width(of:)`), the three columns fit the
/// card's interior at the narrowest window and beside a docked panel,
/// and the row and the headings frame through that one width. What it
/// cannot see: the name column's own need (it wraps, so its floor is
/// taken as zero) and paddings a later change adds beside the ones
/// read here.
///
/// Main-actor spend: one hosted cell per column per catalog, about 33
/// small layouts, measured once.
@Suite("Maximize columns fit (#3255)")
@MainActor
struct MaximizeColumnFitTests {
    private static let codes = LocaleCatalog.availableLocales() + ["en"]

    /// Each column's drawn cell width in `code`, by census id.
    private static func drawn(in code: String) -> [String: CGFloat] {
        LocalizationManager.shared.select(code)
        let row = MaximizeShapeRow(
            model: makeTestModel(),
            shape: .laptop,
            screens: [],
            columns: MaximizeColumns()
        )
        var out: [String: CGFloat] = [:]
        for key in LayoutDefaultsRowOrder.maximizeColumns {
            let host = NSHostingView(rootView: row.cell(key))
            out[key.id] = host.fittingSize.width
        }
        return out
    }

    @Test("every catalog's cells fit their columns and the card")
    func cellsFit() throws {
        defer { LocalizationManager.shared.select("en") }
        #expect(Self.codes.count >= 11, "the catalogs did not list")
        #expect(LayoutDefaultsRowOrder.maximizeColumns.count == 3)
        let spacing = MaximizeShapeRow.spacing
        let section = SettingsMetrics.sectionPlateInset * 2
        let pane = SettingsMetrics.paneInset * 2
        let interiors = [
            SettingsWidthClass.minimum - pane - section,
            SettingsWidthClass.panelBreakpoint - SettingsTheme.panelWidth
                - pane - section,
        ]
        for code in Self.codes {
            let drawn = Self.drawn(in: code)
            let columns = MaximizeColumns(drawn: drawn)
            var total = spacing
            for key in LayoutDefaultsRowOrder.maximizeColumns {
                let cell = try #require(drawn[key.id])
                #expect(cell > 40, "\(code) \(key.id) measured nothing")
                #expect(
                    cell <= columns.width(of: key),
                    "\(code): \(key.id) is \(cell) pt in its column"
                )
                total += columns.width(of: key) + spacing
            }
            for interior in interiors {
                #expect(
                    total <= interior,
                    "\(code): \(total) pt of columns in \(interior) pt"
                )
            }
        }
    }

    /// Every row reports its cells, so a column keeps the widest
    /// of them, in either order.
    @Test("a column keeps its widest row's cell")
    func widestRowWins() {
        for (first, second) in [(100.0, 150.0), (150.0, 100.0)] {
            var drawn: [String: CGFloat] = ["k": first]
            MaximizeColumns.Drawn.reduce(value: &drawn) { ["k": second] }
            #expect(drawn["k"] == 150)
        }
    }

    @Test("the cells and the headings frame through one width")
    func wiring() throws {
        let dir = "Sources/KiwiDesk/Settings/Components/Layouts/"
        func flat(_ name: String) throws -> String {
            try SourceScan.strippedSource(
                at: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(dir + name)
            )
            .filter { !$0.isWhitespace }
        }
        let row = try flat("MaximizeShapeRow.swift")
        #expect(
            row.contains(
                "cell(key).measuredColumn(key)"
                    + ".frame(width:columns.width(of:key),"
            )
        )
        let card = try flat("MaximizeCard.swift")
        #expect(
            card.contains(
                "headingCell(key).multilineTextAlignment(.leading)"
                    + ".fixedSize(horizontal:false,vertical:true)"
                    + ".frame(width:columns.width(of:key),"
            )
        )
        #expect(
            card.contains(
                ".onPreferenceChange(MaximizeColumns.Drawn.self){"
                    + "columns=MaximizeColumns(drawn:$0)"
            )
        )
        #expect(card.components(separatedBy: "columns:columns").count == 3)
        #expect(!card.contains("MaximizeColumns.floor"))
    }
}
