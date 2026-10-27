import Foundation
import Testing

/// A Shortcuts row that holds a setting lays out through the one
/// `ShortcutSettingRow` (#2670), and every shortcut row draws the
/// shortcuts panel's glyph through its one resolver. The recorder
/// footprint is what a hand-built setting row reaches for, so its
/// spellings are held to the register below.
@Suite("Shortcut setting row seam (#2670)")
struct ShortcutSettingRowSeamTests {
    private static let root = SourceScan.repoRoot(from: #filePath)

    /// File basename → why it lays out a recorder footprint itself.
    private static let allowed: [String: String] = [
        "ShortcutSettingRow.swift": "the one shape",
        // #2673 rewrites this row; it adopts the shared shape on
        // rebase, and this entry goes with it.
        "LayoutCycleRow.swift": "#2673 adopts the shared row",
    ]

    @Test("only the shared row lays a setting over the footprint")
    func footprintHasOneHome() throws {
        let settings = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        let files = try SourceScan.swiftSources(under: settings)
        #expect(!files.isEmpty)
        var found: Set<String> = []
        for file in files {
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("KeyRecorderField.footprint") {
                found.insert(file.lastPathComponent)
            }
        }
        #expect(found == Set(Self.allowed.keys))
    }

    @Test("a shortcut row draws the panel's glyph through its resolver")
    func navRowReadsTheResolver() throws {
        let row = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "KeybindingNavRow.swift"
            )
        )
        #expect(row.contains("ShortcutsReferenceBuilder.icon("))
        #expect(!row.contains("command.icon"))
    }
}
