import Foundation
import Testing

@testable import KiwiDesk

/// A Shortcuts section where no row has a keyboard chord keeps no
/// chord slot and no divider, so its badges sit at the column's
/// right edge; a mixed section keeps the #3424 columns, measured per
/// column (#3570, ui-designer 2026-11-23).
@Suite("Shortcuts section chord slot")
@MainActor
struct ShortcutSectionChordSlotTests {
    private let columns = ShortcutColumns(
        badges: true,
        chords: true,
        chord: 60
    )

    private func row(_ id: String, combo: String) -> ShortcutRow {
        ShortcutRow(id: id, label: id, combo: combo)
    }

    @Test("a chordless section drops the chord slot and the divider")
    func chordlessDrops() {
        let kept = ShortcutsSheetView.columns(
            columns,
            keeping: [row("a", combo: ""), row("b", combo: "")]
        )
        #expect(kept?.chords == false)
        #expect(kept?.chord == 0)
        #expect(kept?.badges == true)
    }

    @Test("a section with a chord keeps the column's slot")
    func mixedKeeps() {
        let kept = ShortcutsSheetView.columns(
            columns,
            keeping: [row("a", combo: ""), row("b", combo: "⌃⌥X")]
        )
        #expect(kept == columns)
        #expect(ShortcutsSheetView.columns(nil, keeping: []) == nil)
    }

    /// The section's rows take it, so no section narrows another's.
    @Test("each section's rows take their own slot")
    func sectionsApplyIt() throws {
        let sheet = try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Shortcuts/ShortcutsSheetView.swift"
                )
        )
        .filter { !$0.isWhitespace }
        #expect(
            sheet.contains(
                ".opacity(section.dims?0.6:1)"
                    + ".transformEnvironment(\\.shortcutColumns){"
                    + "$0=Self.columns($0,keeping:section.rows)}"
            )
        )
    }
}
