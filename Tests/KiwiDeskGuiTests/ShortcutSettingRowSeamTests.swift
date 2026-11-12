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
        "ShortcutSettingRow.swift": "the one shape"
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

    /// A strip inside a setting row's footprint hugs its labels at
    /// its own size, or it fills the footprint (#3262,
    /// `docs/ui-patterns.md` ▸ Option tabs). A file building a
    /// setting row is read whole, so a strip it draws outside the
    /// row is held too: the trade for not tracking which closure a
    /// strip sits in.
    @Test("a strip in a setting row hugs its labels")
    func footprintStripsHug() throws {
        let settings = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        var strips = 0
        for file in try SourceScan.swiftSources(under: settings) {
            let source = try SourceScan.strippedSource(at: file)
            guard source.contains("ShortcutSettingRow(") else { continue }
            let chars = Array(source)
            var from = source.startIndex
            while let hit = source.range(
                of: "SegmentedPicker(",
                range: from..<source.endIndex
            ) {
                var cursor =
                    source.distance(
                        from: source.startIndex,
                        to: hit.lowerBound
                    )
                    + "SegmentedPicker".count
                let args = try #require(
                    SourceScan.balanced(
                        chars,
                        from: &cursor,
                        open: "(",
                        close: ")"
                    )
                )
                strips += 1
                #expect(
                    args.contains("hugsLabels: true"),
                    "\(file.lastPathComponent)"
                )
                // A hugging strip still fills a proposed width.
                let next = String(chars[cursor...])
                    .drop(while: \.isWhitespace)
                #expect(
                    next.hasPrefix(".fixedSize()"),
                    "\(file.lastPathComponent)"
                )
                from = hit.upperBound
            }
        }
        #expect(strips > 0)
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

    @Test("a setting row wears the one setting glyph")
    func settingRowWearsTheGlyph() throws {
        let row = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Keybindings/"
                    + "ShortcutSettingRow.swift"
            )
        )
        #expect(row.contains("IconGlyphLabel(icon: Self.settingGlyph)"))
        #expect(row.contains("{ \"slider.horizontal.3\" }"))
    }
}
