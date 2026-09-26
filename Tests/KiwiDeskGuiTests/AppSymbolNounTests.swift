import Foundation
import Testing

/// The App Font option of "App symbol style" is not named with
/// the word that names every app mark (#1690,
/// `.claude/rules/config-vocabulary.md` ▸ glyph vs symbol).
///
/// The defect: the option shipped as "Glyphs" beside "Glyphs per
/// Space" and "Glyph gap", so the cap read as counting App Font
/// symbols only. Every translated catalog carried the same
/// collision somewhere, in its own words.
///
/// Like `ShortcutsPanelNounTests`, this pairs strings ONE catalog
/// already ships rather than reading a vocabulary, so it is not
/// the content-guard predicate Family C rules out. The glyph rows
/// are DERIVED: every key whose English value says "glyph", so a
/// new row joins by being written in the general word.
///
/// What it holds is containment of the option's label, lowercased,
/// inside each glyph row. Its blind spots, the same list the
/// glossary row names, are review's:
///
/// - ONE direction only: a glyph word inside the option's phrase
///   ("Monochrome glyphs") passes;
/// - an English plural escape: "Symbols" is not inside a future
///   "Symbol gap";
/// - inflection: `ru`'s nominative option against the genitive a
///   row takes passes;
/// - the option colliding with the catalog's app-icon word.
///
/// A key a catalog lacks is read from `en.json`, since that is
/// what the user then sees beside the translated rows.
@Suite("The symbol option is not named with the glyph word")
struct AppSymbolNounTests {
    static let option = "app_bar.icon_source.app_font"

    /// Every key whose ENGLISH value uses the general glyph word.
    static func glyphRows(_ english: [String: String]) -> [String] {
        english
            .filter {
                $0.key != option
                    && $0.value.lowercased().contains("glyph")
            }
            .map(\.key)
            .sorted()
    }

    @Test("no catalog names the symbol option with its glyph word")
    func optionIsNotTheGlyphWord() throws {
        let english = try Self.catalog("en")
        let rows = Self.glyphRows(english)
        // The derivation must find the rows #1690 swept, or a
        // reworded English empties the comparison silently.
        #expect(rows.contains("space_bar.glyph_cap"))
        #expect(rows.count > 2)
        let locales = try Self.catalogNames()
        var compared = 0
        for locale in locales {
            let catalog = try Self.catalog(locale)
            let name = try #require(
                catalog[Self.option] ?? english[Self.option]
            ).lowercased()
            for key in rows {
                let label = try #require(
                    catalog[key] ?? english[key]
                ).lowercased()
                compared += 1
                #expect(
                    !label.contains(name),
                    """
                    \(locale): the App Font option reads \
                    "\(name)" and \(key) reads "\(label)" — the \
                    general glyph word names the one option \
                    (#1690). Give the option this catalog's \
                    word for a symbol, or the row its glyph word.
                    """
                )
            }
        }
        // Derived from the set, not a constant: every row in every
        // catalog was actually compared.
        #expect(locales.count > 1)
        #expect(compared == rows.count * locales.count)
    }

    private static func catalogNames() throws -> [String] {
        try FileManager.default
            .contentsOfDirectory(atPath: localesDirectory.path)
            .filter {
                $0.hasSuffix(".json") && !$0.hasPrefix("missing_")
            }
            .map { String($0.dropLast(".json".count)) }
            .sorted()
    }

    private static var localesDirectory: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskGuiTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
            .appendingPathComponent(
                "Sources/KiwiDeskCore/Resources/Locales"
            )
    }

    private static func catalog(_ name: String) throws
        -> [String: String]
    {
        try JSONDecoder().decode(
            [String: String].self,
            from: Data(
                contentsOf:
                    localesDirectory
                    .appendingPathComponent("\(name).json")
            )
        )
    }
}
