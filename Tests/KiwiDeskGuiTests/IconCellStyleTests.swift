import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk

/// An icon picker cell is a chip sized to its grid column: the
/// action chip's padding made it wider than the column, so the
/// cells overlapped and drew pills between them.
@Suite("Icon cell style")
@MainActor
struct IconCellStyleTests {
    /// An `Icons/` source, comments blanked and whitespace gone.
    private func squashed(_ name: String) throws -> String {
        try SourceScan.blankedSource(
            at: SourceScan.repoRoot(from: #filePath).appendingPathComponent(
                "Sources/KiwiDesk/Settings/Components/Icons/" + name
            )
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    @Test("the cell rests and presses on the chip ladder")
    func ladder() {
        #expect(IconCellStyle.fill(pressed: false) == SettingsTheme.chipRest)
        #expect(
            IconCellStyle.fill(pressed: true) == SettingsTheme.chipPressed
        )
    }

    /// The mark is its own layer, so a press never unmarks the
    /// chosen icon (#1173), and the chip ladder's one wash.
    @Test("the mark rides above the press layer")
    func markLayer() throws {
        let face = try squashed("IconCellStyle.swift")
        // One marked wash: the chip ladder's, never a copy.
        #expect(face.contains("ButtonChipStyle.markFill(marked)"))
        let pointer = try #require(
            face.range(of: "shape.fill(IconCellStyle.fill(")
        )
        let mark = try #require(
            face.range(of: "shape.fill(IconCellStyle.markFill(marked))")
        )
        #expect(pointer.lowerBound < mark.lowerBound)
        // A tile, not a chip: an edge on a 40 pt grid reads hard.
        #expect(!face.contains("strokeBorder"))
        // No hover lift, by ruling (#2440).
        #expect(!face.contains(".onHover"))
    }

    /// The grid's cells take the cell style, never the action chip,
    /// and add no fixed width the column cannot hold.
    @Test("the grid cell wears the cell style")
    func cellWiring() throws {
        let source = try squashed("IconPicker.swift")
        let start = try #require(
            source.range(of: "privatefunccell(_glyph:String)")
        )
        let end = try #require(
            source.range(
                of: "privatevarrecentChoices",
                range: start.upperBound..<source.endIndex
            )
        )
        let cell = source[start.upperBound..<end.lowerBound]
        #expect(cell.contains("letmarked=!icon.isEmpty&&glyph==icon"))
        #expect(
            cell.contains(".buttonStyle(IconCellStyle(marked:marked))")
        )
        #expect(
            cell.contains(".accessibilityAddTraits(marked?.isSelected:[])")
        )
        #expect(!cell.contains(".settingsActionButton()"))
        #expect(!cell.contains(".frame(width:"))
    }
}
