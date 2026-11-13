import Foundation
import Testing

@testable import KiwiDesk

/// A row glyph is drawn through `ShortcutGlyphView` alone (#3267 ▸
/// Ruling 1): no file that holds a `ShortcutGlyph` reads its kind or
/// draws it another way, and the files that draw one are the
/// register below.
///
/// Trades, stated: a holder is found by WORDS (`holds`), not by
/// type, so a file reaching a row's glyph through another binding
/// name (`entry.icon`) and never spelling the type is not scanned;
/// `knownHolders` floors the matched set so a needle that stops
/// matching reds. `IconGlyphLabel` is banned only with a `glyph` or
/// `icon` argument, and a layer icon still held as a `String`
/// (`ShortcutsFamilyRows.layerIcons`) is upstream of the door, so
/// neither catches every spelling; review holds the rest.
@Suite("Shortcut glyph door (#3267)")
struct ShortcutGlyphDoorTests {
    private static let root = SourceScan.repoRoot(from: #filePath)
    private static let door = "Shortcuts/ShortcutGlyph.swift"

    /// Who draws a `ShortcutGlyph`; a new surface joins with its view.
    private static let drawers: Set<String> = [
        "Settings/Components/Keybindings/KeybindingNavRow.swift",
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceActionMenu+Trigger.swift",
        "Settings/Components/Keybindings/Sequences/"
            + "SequenceActionMenu.swift",
        "Settings/Components/Simple/SimpleKiwiHubKeys.swift",
        "Settings/Sections/ShortcutLayerChip.swift",
        "Shortcuts/ShortcutsBands.swift",
    ]

    /// The words a file holding a glyph uses: the type, the resolver,
    /// or a row's icon.
    private static let holds = [
        "ShortcutGlyph", "ShortcutsReferenceBuilder.icon(", "row.icon",
        "drawn.icon",
    ]

    /// Files that hold a glyph today; the scan must reach each.
    private static let knownHolders =
        drawers.union([
            "Shortcuts/ShortcutsReference+Glyphs.swift",
            "Shortcuts/ShortcutFold.swift",
        ])

    /// What reading a glyph's kind or drawing it beside the door looks
    /// like. Bare `case.symbol` takes every `if case`, `guard case`
    /// and `switch` arm, at the cost of a holder never naming another
    /// enum's `.symbol` case.
    private static let banned = [
        "case.emoji", "case.symbol", "caselet.emoji", "caselet.symbol",
        "IconGlyphLabel(icon:glyph", "IconGlyphLabel(icon:icon",
        "Image(systemName:$0)",
    ]

    private func sources() throws -> [(path: String, flat: String)] {
        let tree = Self.root.appendingPathComponent("Sources/KiwiDesk")
        return try SourceScan.swiftSources(under: tree).map { url in
            let path = String(
                url.path.dropFirst(tree.path.count + 1)
            )
            let flat = try SourceScan.strippedSource(at: url)
                .filter { !$0.isWhitespace }
            return (path, flat)
        }
    }

    @Test("no file holding a glyph reads its kind or draws it itself")
    func noSurfaceBranches() throws {
        let files = try sources()
        let holders = files.filter {
            $0.path != Self.door
                && Self.holds.contains(where: $0.flat.contains)
        }
        #expect(
            Self.knownHolders.isSubset(of: Set(holders.map(\.path))),
            "the holder needles stopped matching"
        )
        for file in holders {
            for needle in Self.banned {
                #expect(
                    !file.flat.contains(needle),
                    "\(file.path) spells \(needle)"
                )
            }
        }
    }

    @Test("the files that draw a glyph are the register")
    func drawersAreTheRegister() throws {
        let drawing = Set(
            try sources().filter {
                $0.path != Self.door
                    && $0.flat.contains("ShortcutGlyphView(glyph:")
            }.map(\.path)
        )
        #expect(drawing == Self.drawers)
    }
}
