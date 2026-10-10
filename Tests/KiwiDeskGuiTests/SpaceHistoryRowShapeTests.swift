import Foundation
import Testing

/// The Space history group (#1655, owner 2026-10-10): a heading like
/// the per-Space families, then a row naming the current behaviour
/// in a menu — two peers, neither an "off", so never a checkbox —
/// at the start of its line, its "Applies to" control in the
/// shortcut rows' reach column ahead of the recorder footprint.
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

    @Test("a heading, then the menu ahead of reach and the footprint")
    func groupOrder() throws {
        let row = try source()
        let heading = try #require(
            row.range(of: ".accessibilityAddTraits(.isHeader)")
        )
        let menu = try #require(row.range(of: "                menu\n"))
        let reach = try #require(row.range(of: "                reach\n"))
        let footprint = try #require(
            row.range(of: "KeyRecorderField.footprint")
        )
        #expect(heading.upperBound <= menu.lowerBound)
        #expect(menu.upperBound <= reach.lowerBound)
        #expect(reach.upperBound <= footprint.lowerBound)
    }
}
