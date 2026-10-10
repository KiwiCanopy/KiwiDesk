import Foundation
import Testing

/// The Space history row is a checkbox (#1655, owner 2026-10-10):
/// a binary is a toggle (`docs/ui-patterns.md`), on meaning one
/// history across every screen, and the row keeps the shortcut
/// rows' shape so its reach control sits in their column.
@Suite("Space history row shape (#1655)")
struct SpaceHistoryRowShapeTests {
    private func source() throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Keybindings/"
                        + "SpaceHistoryRow.swift"
                )
        )
    }

    @Test("one checkbox, never two segments")
    func isACheckbox() throws {
        let row = try source()
        #expect(row.occurrences(of: ".toggleStyle(.checkbox)") == 1)
        #expect(row.occurrences(of: "SegmentedPicker") == 0)
    }

    @Test("on is all screens, off per screen")
    func checkedMeansAllScreens() throws {
        let row = try source()
            .split(whereSeparator: \.isWhitespace).joined()
        #expect(row.contains("get:{model.config.spaceHistory==.allScreens}"))
        #expect(
            row.contains(
                "model.config.spaceHistory=$0?.allScreens:.perScreen"
            )
        )
    }

    @Test("the reach control sits in the recorder rows' column")
    func reachSitsBesideTheFootprint() throws {
        let row = try source()
        let reach = try #require(row.range(of: "                reach\n"))
        let footprint = try #require(
            row.range(of: "KeyRecorderField.footprint")
        )
        #expect(reach.upperBound <= footprint.lowerBound)
    }
}
