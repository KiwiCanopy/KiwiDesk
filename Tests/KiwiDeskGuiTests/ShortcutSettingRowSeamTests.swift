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
        "GestureDirectionRows.swift":
            "a split gesture row's sub-row echoes the row's keys in "
            + "the recorder column, read-only (#3281)",
    ]

    /// File basename → the setting rows it builds through the one
    /// shape, and why each is a setting rather than a key row.
    private static let settingRows: [String: String] = [
        "FocusWrapRow.swift": "focus wrap, a choice of reach",
        "LayoutCycleRow.swift": "the layouts a cycle key walks",
        "ShortcutBaseRow.swift": "which base the shortcuts start from",
        "SpaceHistoryRow.swift": "how the Space history is kept",
        "TilingOffRows.swift": "what a Space without tiling does",
        "GestureListCard.swift":
            "Natural scrolling, a value over the gesture rows' "
            + "recorders (#3281)",
    ]

    @Test("every setting row is registered with its reason")
    func settingRowsAreRegistered() throws {
        let settings = Self.root.appendingPathComponent(
            "Sources/KiwiDesk/Settings"
        )
        var found: Set<String> = []
        for file in try SourceScan.swiftSources(under: settings) {
            let source = try SourceScan.strippedSource(at: file)
            if source.contains("ShortcutSettingRow(") {
                found.insert(file.lastPathComponent)
            }
        }
        #expect(!found.isEmpty)
        #expect(found == Set(Self.settingRows.keys))
    }

    /// The gesture cards' Natural scrolling row is a setting row,
    /// never a hand-built one beside it (#3281).
    @Test("the gesture cards' Natural scrolling row takes the shape")
    func naturalRowTakesTheShape() throws {
        let card = try SourceScan.strippedSource(
            at: Self.root.appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Gestures/"
                    + "GestureListCard.swift"
            )
        )
        let row = try #require(
            SourceScan.declarationBody(
                after: "private var naturalRow:",
                in: card
            )
        )
        #expect(row.contains("ShortcutSettingRow("))
        #expect(row.contains("reach: { naturalReach }"))
        #expect(row.contains("control: { naturalPicker }"))
        #expect(row.contains("SettingsMetrics.shortcutTextIndent"))
        #expect(!row.contains("HStack"))
        let picker = try #require(
            SourceScan.declarationBody(
                after: "private var naturalPicker:",
                in: card
            )
        )
        #expect(picker.contains(".pickerStyle(.menu)"))
        #expect(!picker.contains("SegmentedPicker("))
    }

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
