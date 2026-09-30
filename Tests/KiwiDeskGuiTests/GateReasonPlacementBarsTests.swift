import Foundation
import Testing

/// A grey the census cannot see drawn where its reader looks —
/// split from `GateReasonPlacementTests` at the file ceiling.
@Suite("Gate reason placement — the Bars cards")
struct GateReasonPlacementBarsTests {
    /// The KiwiShelf card greys every row but the Show switches
    /// while no bar can show — a grey on the card's own block,
    /// read from the resolver, which no other suite reaches.
    @Test("the KiwiShelf card greys its rows while no bar shows")
    func theShelfCardGreysWithoutABar() throws {
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "Bars/KiwiShelfCard.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        let show = try #require(source.range(of: "showGroupVStack("))
        let grey = try #require(
            source.range(
                of: "marginsDisclosure}.modifier(GreyOut("
                    + "active:!gates.shelfShows,"
                    + "help:BarsGateHelp.sentence(for:.shelfEmpty)"
            )
        )
        // The Show switches sit OUTSIDE the grey, or nothing
        // could turn a bar back on.
        #expect(show.upperBound < grey.lowerBound)
    }
}
