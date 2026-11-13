import Foundation
import Testing

@testable import KiwiDesk

/// In KiwiHub, rows fill and tiles ring (#3210, gui.md): a tile —
/// the app strip's, a layout tile, a Desktops icon — marks its
/// selection with a 2 pt `paint.selection` ring and draws in its
/// unselected inks, while a row keeps the solid selection fill.
/// Source scans, since a fill and a ring render alike to no test.
@Suite("KiwiHub tiles ring, rows fill")
struct KiwiHubTileSelectionTests {
    private static func squashed(_ file: String) throws -> String {
        try SourceScan.strippedSource(
            at: SourceScan.repoRoot(from: #filePath)
                .appendingPathComponent("Sources/KiwiDesk/Jump/" + file)
        ).split(whereSeparator: \.isWhitespace).joined()
    }

    /// The strip's tile, cut from the strip file.
    private static func stripTile() throws -> String {
        let source = try squashed("JumpStripView.swift")
        let start = try #require(
            source.range(of: "structJumpStripTile:View{")
        )
        let rest = source[start.upperBound...]
        let end = try #require(rest.range(of: "structJumpYoursLine"))
        return String(rest[..<end.lowerBound])
    }

    private static let ring = "strokeBorder(paint.selection,lineWidth:2)"
    private static let filledLift =
        "paint.selectionInk.opacity(paint.filledLift)"

    @Test("each tile rings its selection and never fills it")
    func tilesRing() throws {
        let tiles = [
            ("JumpStripTile", try Self.stripTile()),
            ("JumpLayoutTile", try Self.squashed("JumpLayoutTile.swift")),
            ("DesktopIconView", try Self.squashed("DesktopIconView.swift")),
        ]
        for (name, body) in tiles {
            #expect(!body.isEmpty, "\(name)")
            #expect(body.occurrences(of: Self.ring) == 1, "\(name)")
            // `selectionInk` is the filled row's hover lift alone.
            let lifts = body.occurrences(of: Self.filledLift)
            #expect(
                body.occurrences(of: "paint.selection") - lifts
                    == body.occurrences(of: Self.ring),
                "\(name) draws the selection colour off its ring"
            )
            // Its inks are the unselected ones.
            #expect(!body.contains("selected:isSelected,lifted"), "\(name)")
            #expect(
                body.occurrences(of: "paint.selectionInk") == lifts,
                "\(name)"
            )
            // Only a Desktops icon sits on a filled row.
            #expect(
                lifts == (name == "DesktopIconView" ? 1 : 0),
                "\(name)"
            )
        }
    }

    @Test("the strip draws no caret and its plates take no hover fill")
    func stripPlatesAreNeutral() throws {
        let tile = try Self.stripTile()
        #expect(!tile.contains("Capsule().fill(isSelected"))
        // The ground's lift is the one hover fill on the tile.
        #expect(tile.occurrences(of: "paint.rowHover") == 1)
        #expect(tile.occurrences(of: ".fill(.quaternary)") == 2)
    }

    /// On a filled line a tile's hover lifts in the line's ink; the
    /// line decides the fill once and hands it over (#3264).
    @Test("a tile's hover on a filled line lifts in its ink")
    func filledLineHover() throws {
        let icon = try Self.squashed("DesktopIconView.swift")
        #expect(
            icon.contains(
                ".fill(onFill?AnyShapeStyle(\(Self.filledLift))"
                    + ":paint.fill(paint.rowHover))"
            )
        )
        #expect(icon.occurrences(of: "paint.rowHover") == 1)
        let line = try Self.squashed("DesktopLineView.swift")
        #expect(line.contains("onFill:wearsFill,"))
        // A drop target's tint keeps the bare-row hover (#3264).
        #expect(
            line.contains(
                "privatevarwearsFill:Bool{"
                    + "!isTarget&&isSelected&&!state.isInside}"
            )
        )
        #expect(line.contains("}elseifwearsFill{shape.fill("))
        #expect(line.occurrences(of: "onFill:") == 1)
    }

    @Test("a Desktops line keeps the row's selection fill")
    func rowsFill() throws {
        let line = try Self.squashed("DesktopLineView.swift")
        #expect(
            line.contains(
                "}elseifwearsFill{"
                    + "shape.fill(paint.fill(paint.selection))"
            )
        )
    }
}
