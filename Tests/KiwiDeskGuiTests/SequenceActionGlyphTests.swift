import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The action menu's catalogue rows wear the Shortcuts catalogue's
/// glyph for their command (#3283): the menu owns no symbol of its
/// own (gui.md #2670), and both callers — a gesture row and a key
/// sequence's end key — share the one row builder, so one wiring
/// covers both. A command with no glyph keeps the empty column.
///
/// Trades, stated: the needles are read inside the two function
/// bodies, so a row drawn by a builder of another name is review's.
@Suite("Action menu catalogue glyphs (#3283)")
struct SequenceActionGlyphTests {
    private static let directory =
        "Settings/Components/Keybindings"
        + "/Sequences"

    private func body(of function: String) throws -> String {
        try SourceScan.functionBody(
            of: function,
            in: "SequenceActionMenu.swift",
            under: Self.directory,
            root: "Sources/KiwiDesk"
        ).filter { !$0.isWhitespace }
    }

    @Test("a catalogue row draws its command's glyph")
    func rowDrawsTheGlyph() throws {
        let row = try body(of: "row")
        #expect(!row.isEmpty)
        #expect(row.contains("catalogueGlyph(command)"))
    }

    @Test("the glyph is the catalogue's, through the one door")
    func glyphIsTheCatalogues() throws {
        let glyph = try body(of: "catalogueGlyph")
        #expect(!glyph.isEmpty)
        #expect(
            glyph.contains("ShortcutsReferenceBuilder.icon(for:command)")
        )
        #expect(glyph.contains("ShortcutGlyphView(glyph:glyph)"))
        // The empty slot keeps the row glyph's square.
        #expect(glyph.contains("ShortcutGlyphView.rowSide"))
    }

    @Test("every catalogue command has a glyph to draw")
    @MainActor
    func everyCommandHasAGlyph() {
        let expander = ShortcutsFamilyRows(
            spaces: ["1", "2", "mail"],
            icons: [:],
            desktops: KeybindingCatalog.DesktopOffer(desktops: [1, 2]),
            resizeStep: 42,
            layerNames: [KeyLayer.defaultName, "Mouse"],
            currentLayer: KeyLayer.defaultName,
            lenses: ["Writing"]
        )
        let commands = SequenceActionCatalog(expander: expander)
            .groups.flatMap(\.commands)
        #expect(commands.count > 40, "the catalogue built too few rows")
        for command in commands {
            #expect(
                ShortcutsReferenceBuilder.icon(for: command) != nil,
                "\(command.lua) draws no glyph"
            )
        }
    }
}
