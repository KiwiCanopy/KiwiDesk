import Foundation
import Testing

/// The Space history row names its current behaviour (#1655, owner
/// 2026-10-10): two peers, neither an "off", so a compact menu over
/// the kinds — never a checkbox, whose off-state reads as absence —
/// in the shortcut rows' shape, its reach control in their column.
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

    @Test("a menu over the kinds, never a checkbox or segments")
    func isAMenu() throws {
        let row = try source()
        #expect(row.occurrences(of: ".pickerStyle(.menu)") == 1)
        #expect(row.contains("ForEach(SpaceHistoryKind.allCases"))
        #expect(row.occurrences(of: ".toggleStyle(") == 0)
        #expect(row.occurrences(of: "SegmentedPicker") == 0)
    }

    @Test("the menu sits in the recorder column, reach beside it")
    func menuSitsInTheRecorderColumn() throws {
        let row = try source()
        let reach = try #require(row.range(of: "                reach\n"))
        let footprint = try #require(
            row.range(of: "KeyRecorderField.footprint")
        )
        let menu = try #require(row.range(of: "                    menu\n"))
        #expect(reach.upperBound <= footprint.lowerBound)
        #expect(footprint.upperBound <= menu.lowerBound)
    }
}
