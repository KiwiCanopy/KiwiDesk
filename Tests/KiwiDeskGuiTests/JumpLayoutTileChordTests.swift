import Foundation
import Testing

/// A layout tile's quick-apply chord sits on its own line under
/// the name (owner ruling 2026-10-13, #2245): drawn over the
/// schematic it covered the picture, and beside the name it cut
/// the name off. The line keeps its height while ⌘ is up, so the
/// panel never resizes on a press.
@Suite("A layout tile's chord sits under its name")
struct JumpLayoutTileChordTests {
    @Test("the chord is a line of the tile, never an overlay")
    func chordIsALine() throws {
        let tile = try Self.tileSource()
        #expect(tile.occurrences(of: ".overlay(") == 0)
        let content = try #require(Self.body(of: "content", in: tile))
        #expect(content.occurrences(of: "numberMark") == 1)
    }

    @Test("the chord's line is held while ⌘ is up")
    func lineIsHeld() throws {
        let tile = try Self.tileSource()
        let mark = try #require(Self.body(of: "numberMark", in: tile))
        #expect(mark.occurrences(of: "if showsNumber") == 0)
        #expect(
            mark.occurrences(of: ".opacity(showsNumber ? 1 : 0)") == 1
        )
    }

    @Test("VoiceOver hears the tile's chord with ⌘ up or down")
    func chordIsSpoken() throws {
        let tile = try Self.tileSource()
        let hint =
            ".accessibilityHint("
            + "LayoutPickText.chordHint(\"⌘\\(number)\"))"
        #expect(tile.occurrences(of: hint) == 1)
    }

    /// The brace-balanced body of computed property `name`.
    private static func body(of name: String, in source: String)
        -> String?
    {
        guard
            let head = source.range(of: "var \(name): some View {")
        else { return nil }
        var depth = 1
        var index = head.upperBound
        while index < source.endIndex, depth > 0 {
            if source[index] == "{" { depth += 1 }
            if source[index] == "}" { depth -= 1 }
            index = source.index(after: index)
        }
        return depth == 0 ? String(source[head.upperBound..<index]) : nil
    }

    /// `JumpLayoutTile`'s declaration, comments stripped.
    private static func tileSource() throws -> String {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpLayoutsView.swift"
                    ),
                encoding: .utf8
            )
        )
        let start = try #require(
            source.range(of: "struct JumpLayoutTile: View {")
        )
        return String(source[start.lowerBound...])
    }
}
