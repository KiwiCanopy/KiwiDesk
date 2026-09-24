import Foundation
import Testing

/// The App Bar's Content row draws its inline reason (#1517): the
/// census derives `.inline` for it (the edge lives on the KiwiShelf
/// card), and nothing else watches that the row DRAWS what the
/// derivation owes — guard-prover found the drawing deletable with
/// every suite green. Split from `GateReasonPlacementTests` at the
/// file ceiling.
@Suite("Gate reason placement — the App Bar Content row")
struct GateReasonPlacementBarsTests {
    @Test("the Content row draws its reason outside the dim")
    func theContentRowDrawsItsReason() throws {
        let path = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/"
                    + "Bars/AppBarCard+ContentRows.swift"
            )
        let source = SourceScan.stripComments(
            try String(contentsOf: path, encoding: .utf8)
        )
        .split(whereSeparator: \.isWhitespace)
        .joined()
        let dim = try #require(
            source.range(
                of: ".modifier(GreyOut(active:gates.everyShownBarVertical"
            )
        )
        // The reason is a SIBLING after the dimmed picker, drawn
        // off the derivation and in the row's note shape.
        let sentence = try #require(
            source.range(
                of: "ifgates.everyShownBarVertical,"
                    + "GateReasonPlacement.owesInlineReason("
                    + ".appBar(.appBarContent)){"
                    + "BarNoteRow(text:contentVerticalReason)"
            )
        )
        #expect(dim.upperBound < sentence.lowerBound)
    }
}
