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
/// the content-guard predicate Family C rules out. It holds
/// containment only: the option's label, lowercased, must not
/// appear inside either glyph label. An INFLECTED reuse passes —
/// `ru`'s nominative option against the genitive its cap label
/// takes — and stays with review; so does the option colliding
/// with the catalog's app-icon word, which the glossary row
/// also forbids.
///
/// A key a catalog lacks is read from `en.json`, since that is
/// what the user then sees beside the translated rows.
@Suite("The symbol option is not named with the glyph word")
struct AppSymbolNounTests {
    static let option = "app_bar.icon_source.app_font"
    static let glyphLabels = [
        "space_bar.glyph_cap", "space_bar.glyph_gap",
    ]

    @Test("no catalog names the symbol option with its glyph word")
    func optionIsNotTheGlyphWord() throws {
        let english = try Self.catalog("en")
        var compared = 0
        for locale in try Self.catalogNames() {
            let catalog = try Self.catalog(locale)
            let name = try #require(
                catalog[Self.option] ?? english[Self.option]
            ).lowercased()
            for key in Self.glyphLabels {
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
                    word for a symbol.
                    """
                )
            }
        }
        // Counts comparisons, not files: a catalog directory
        // that decoded to nothing must not pass.
        #expect(compared > Self.glyphLabels.count)
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
