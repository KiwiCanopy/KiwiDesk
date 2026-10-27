import Foundation
import Testing

/// The Space history group (#1655, owner 2026-10-10): a heading like
/// the per-Space families, then a row naming the current behaviour
/// in a menu — two peers, neither an "off", so never a checkbox —
/// in the shared setting row (#2670): its "Applies to" control in
/// the reach column, the menu in the recorder's footprint.
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

    @Test("a heading, then the shared setting row with reach and menu")
    func groupOrder() throws {
        let row = try source()
        let heading = try #require(
            row.range(of: ".accessibilityAddTraits(.isHeader)")
        )
        let shared = try #require(row.range(of: "ShortcutSettingRow("))
        #expect(heading.upperBound <= shared.lowerBound)
        // The columns are the shared row's (#2670): reach ahead of
        // the footprint the menu sits in.
        #expect(row.contains("reach: { reach }"))
        #expect(row.contains("control: { menu }"))
        let shape = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Keybindings/"
                        + "ShortcutSettingRow.swift"
                )
        )
        let reach = try #require(shape.range(of: "            reach\n"))
        let footprint = try #require(
            shape.range(of: "KeyRecorderField.footprint.overlay { control }")
        )
        #expect(reach.upperBound <= footprint.lowerBound)
    }
}
