import Foundation
import KiwiDeskCore
import SwiftUI
import Testing

@testable import KiwiDesk

/// A layout tile's schematic takes the hover ink lifted under "Tint
/// KiwiHub and plates", so no accent stroke sits on a highlight
/// (#2569); a selected tile's ring leaves the brand's schematic
/// (#3210), and so does the grey lift untinted.
@Suite("A KiwiHub tile's schematic takes its fill's ink")
struct KiwiHubTileSchematicTests {
    private func tinted() -> KiwiHubPaint {
        var shelf = KiwiShelf()
        shelf.highlightColor = "#564AB6"
        shelf.hoverFillColor = "#AACB5D80"
        shelf.hoverItemColor = "#EAF3EE"
        return KiwiHubPaint(
            shelf,
            divider: "#FFFFFF33",
            axis: nil,
            increaseContrast: false
        )
    }

    @Test("a lifted tile's schematic is drawn in the hover ink")
    func liftedTakesHoverInk() throws {
        let paint = tinted()
        let ink = try #require(paint.hoverInk)
        let palette = try #require(
            paint.schematicPalette(lifted: true)
        )
        #expect(palette.accent == ink)
        #expect(palette.ink == ink)
        #expect(palette.base == paint.rowHover)
    }

    @Test("a resting tile, or a lifted one untinted, keeps the brand's")
    func restAndUntintedKeepBrand() {
        #expect(
            tinted().schematicPalette(lifted: false) == nil
        )
        #expect(
            KiwiHubPaint().schematicPalette(lifted: true) == nil
        )
        // Untinted reads `tinted`, never a nil hover ink alone.
        var untinted = KiwiHubPaint()
        untinted.hoverInk = .white
        #expect(
            untinted.schematicPalette(lifted: true) == nil
        )
    }

    @Test("the tile hands its schematic the paint's palette")
    func tileReadsThePaint() throws {
        let source = SourceScan.stripComments(
            try String(
                contentsOf: SourceScan.repoRoot(from: #filePath)
                    .appendingPathComponent(
                        "Sources/KiwiDesk/Jump/JumpLayoutTile.swift"
                    ),
                encoding: .utf8
            )
        )
        #expect(
            source.occurrences(
                of: "paint.schematicPalette(lifted: isLifted)"
            ) == 1
        )
        #expect(source.occurrences(of: "\\.schematicPalette,") == 1)
    }
}
