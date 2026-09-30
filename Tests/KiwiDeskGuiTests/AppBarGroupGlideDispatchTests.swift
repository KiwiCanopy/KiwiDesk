import Foundation
import Testing

@testable import KiwiDesk

/// The App Bar render dispatches its two animation groups — the
/// frame pass and the glass pass — through ONE choice: a render
/// that folds or releases group members rides the plate glide,
/// every other one the item slide (#1831, #1837). A site that
/// named a group directly would put the boxes on one clock and
/// the items on another.
///
/// A source scan because the choice is a ternary between two
/// `BarMotion` entry points, which no headless render can tell
/// apart: both land at once in a test.
@Suite("App Bar group glide dispatch (#1837)")
struct AppBarGroupGlideDispatchTests {
    private static func renderSource() throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("Bar")
            .appendingPathComponent("AppBarOverlay.swift")
        let text = try String(contentsOf: url, encoding: .utf8)
        let stripped = SourceScan.stripComments(text)
        try #require(!stripped.isEmpty)
        return stripped
    }

    @Test("Both group passes take the one groups-or-not choice")
    func bothPassesTakeTheChoice() throws {
        let source = try renderSource()
        let choice =
            "(groups ? BarMotion.runPlateGlide : BarMotion.runLayout) {"
        #expect(source.components(separatedBy: choice).count - 1 == 2)
        // No pass names a group on its own beside the choice.
        for bare in ["BarMotion.runLayout {", "BarMotion.runPlateGlide {"] {
            #expect(
                !source.contains(bare),
                Comment(rawValue: "bare \(bare) in AppBarOverlay.render")
            )
        }
    }
}
