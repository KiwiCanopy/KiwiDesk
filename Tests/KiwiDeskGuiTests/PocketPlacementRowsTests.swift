import Foundation
import Testing

@testable import KiwiDesk

/// The Pocket's rows on KiwiShelf's card (#3401): its edge and
/// its screens sit in Position's drawer on the doors a bar's take,
/// and the Pocket position row shows its rule under itself while
/// the pocket shares a bar's edge, in its `?` otherwise. Source
/// needles, whitespace stripped; off the main actor, two file
/// reads.
@Suite("Pocket placement rows (#3401)")
struct PocketPlacementRowsTests {
    private static let bars = "Sources/KiwiDesk/Settings/Components/Bars/"

    private func source(_ file: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(Self.bars + file)
        return try SourceScan.strippedSource(at: url)
            .filter { !$0.isWhitespace }
    }

    /// `text` from `start` to the next `end`, or "".
    private func span(_ text: String, from start: String, to end: String)
        -> String
    {
        guard let open = text.range(of: start),
            let close = text.range(
                of: end,
                range: open.upperBound..<text.endIndex
            )
        else { return "" }
        return String(text[open.lowerBound..<close.upperBound])
    }

    @Test("the drawer draws the Pocket's edge and its screens")
    func drawerHoldsThePocket() throws {
        let edge = try source("KiwiShelfCard+Edge.swift")
        let drawer = span(edge, from: "varedgeRows", to: "varspaceBarEdgeRow")
        #expect(drawer.contains("pocketEdgeRow"))
        #expect(drawer.contains("bar:\\.kiwishelf.pocketEdges,"))
        #expect(drawer.contains(".kiwishelfPocketScreenEdges"))
        let row = span(
            edge,
            from: "varpocketEdgeRow",
            to: ".kiwishelfPocketEdge"
        )
        #expect(row.contains("model.barEdge(\\.kiwishelf.pocketEdges)"))
        #expect(row.contains("BarsGateHelp.pocketScreensDiffer"))
    }

    @Test("the rule shows under the row only while it applies")
    func noteFollowsTheVerdict() throws {
        let pocket = try source("KiwiShelfCard+Pocket.swift")
        #expect(
            pocket.contains(
                "varpocketNoteShown:Bool{"
                    + "model.config.settings.pocketSharesABarEdge}"
            )
        )
        #expect(
            pocket.contains(
                "ifpocketNoteShown{"
                    + "BarNoteRow(text:Self.pocketPositionNote)}"
            )
        )
        #expect(
            pocket.contains(
                "help:pocketNoteShown?nil:Self.pocketPositionNote"
            )
        )
        let rows = try source("KiwiShelfCard+Rows.swift")
        #expect(rows.contains("case.pocketPosition:pocketPositionRows"))
    }

    @Test("the position slider marks no middle")
    func sliderHasNoOrigin() throws {
        let pocket = try source("KiwiShelfCard+Pocket.swift")
        let slider = span(pocket, from: "SettingsSlider(", to: "ends:")
        #expect(!slider.isEmpty)
        #expect(!slider.contains("origin:"))
    }
}
