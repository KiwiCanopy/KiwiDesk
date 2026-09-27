import Foundation
import Testing

/// The font family picker's two event paths (#1681): a pointer
/// moves the highlight and never scrolls — a hover that scrolled
/// the list moved the next row under a still pointer, over and
/// over — and the search takes its highlight from the one static
/// rule `BarFontSettingsTests` ▸ `highlightRule` holds. Both are
/// wiring no runtime clause can see, so they are pinned in the
/// picker's source.
@Suite("Font family picker wiring")
struct FontFamilyPickerSeamTests {
    static func source() throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent(
                    "Sources/KiwiDesk/Settings/Components/Bars/"
                        + "FontFamilyPicker.swift"
                )
        )
    }

    @Test("a hover sets the highlight and never the scroll target")
    func hoverNeverScrolls() throws {
        let text = try Self.source()
        let hover = try #require(
            SourceScan.declarationBody(after: ".onHover", in: text)
        )
        #expect(hover.contains("highlighted ="))
        #expect(
            !hover.contains("scrollTarget"),
            "the hover handler scrolls the list again"
        )
        // The scroll target has exactly two writers: the keyboard
        // step and the search handler.
        let move = try #require(
            SourceScan.declarationBody(after: "func move(", in: text)
        )
        let search = try #require(
            SourceScan.declarationBody(
                after: ".onChange(of: search)",
                in: text
            )
        )
        #expect(move.occurrences(of: "scrollTarget =") == 1)
        #expect(search.occurrences(of: "scrollTarget =") == 1)
        #expect(
            text.occurrences(of: "scrollTarget =") == 2,
            "a third writer of the scroll target"
        )
    }

    @Test("the search takes its highlight from the static rule")
    func searchAsksTheRule() throws {
        let search = try #require(
            SourceScan.declarationBody(
                after: ".onChange(of: search)",
                in: try Self.source()
            )
        )
        let call = try #require(
            SourceScan.callArguments(of: "highlight(", in: search),
            "the search handler no longer asks the highlight rule"
        )
        #expect(call.contains("query:"))
    }
}
