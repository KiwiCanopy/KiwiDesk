import Foundation
import Testing

/// Exercises the dropped-feature-name guard: the GUI ships
/// "App Bar" and "Space Bar" untranslated in **every** locale, so
/// every locale must carry them verbatim, script irrelevant.
///
/// `GLOSSARY` already *exempted* these words from the residue
/// guard; nothing checked that anyone kept them, and `de` had
/// rendered all 25 of its occurrences as "App-Leiste" /
/// "Space-Leiste".
///
/// The guard is deliberately NOT the mirror of `english_residue`,
/// though an earlier cut scoped it that way. Residue asks whether
/// a word was *forgotten*, which is a judgment about the sentence
/// around it and so is script-sensitive. This asks whether a name
/// the interface never translates was translated anyway — true
/// regardless of script, in the same way "KiwiDesk", "Lua" and
/// "BSP" stay English everywhere.
///
/// Fixtures are text the test writes itself, never the shipped
/// catalogs — asserting against the corpus would make the guard's
/// coverage depend on the corpus staying dirty.
@Suite("extract-keys feature-name guard")
struct LocalizationProductNameGuardTests {
    /// The defect as it actually shipped: German compounds the
    /// name into its own words.
    @Test(
        "a Latin-script locale translating the name fails",
        arguments: [
            ("de", "App Bar", "App-Leiste"),
            ("de", "Show Space Bar", "Space-Leiste anzeigen"),
            ("fr", "Space Bar colors", "Couleurs de la barre"),
            ("it", "App Bar", "Barra delle app"),
            ("pt-BR", "Space Bar style", "Estilo da barra"),
            ("es", "App Bar appearance", "Apariencia de barra"),
        ]
    )
    func translatedNameFails(
        locale: String,
        english: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: locale,
            english: english,
            value: value
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("feature name"))
    }

    /// The four locales that already got this right must stay
    /// silent — otherwise the guard would be reporting the fix as
    /// the defect.
    @Test(
        "keeping the name verbatim passes",
        arguments: [
            ("de", "App Bar", "App Bar"),
            (
                "fr", "Space Bar colors",
                "Couleurs de la Space Bar"
            ),
            (
                "it", "Show app bar",
                "Mostra la App Bar"
            ),
            (
                "pt-BR",
                "The App Bar appears in Monocle and Scrolling.",
                "A App Bar aparece em Monocle e Scrolling."
            ),
        ]
    )
    func verbatimNamePasses(
        locale: String,
        english: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: locale,
            english: english,
            value: value
        )
        #expect(result.status == 0)
    }

    /// **Presence, not parity** — the semantics every other pass
    /// fixture here happens to leave unpinned, because each is 1:1
    /// in mention count. The guard asks whether the name survives
    /// at all, never how often: dropping a redundant repetition of
    /// a proper noun is normal translation practice, and the defect
    /// this was written for was locales *renaming* the feature,
    /// never mentioning it fewer times.
    ///
    /// Unpinned, "tighten it to parity" is a one-line change that
    /// breaks no test and reads like a strengthening, which is
    /// what makes it likely. It is a regression: parity rejects a
    /// translation naming the bar once where the English named it
    /// twice — ordinary practice, not a dropped name — and pushes
    /// the translator toward a literal, worse sentence to satisfy
    /// the tool. `docs/translating.md` states the rule; this makes
    /// breaking it fail.
    @Test(
        "fewer mentions than the English still passes",
        arguments: [
            (
                "de",
                "The App Bar lists windows. The App Bar is optional.",
                "Die App Bar listet Fenster. Sie ist optional."
            ),
            (
                "fr",
                "Space Bar colors and Space Bar position",
                "Couleurs et position de la Space Bar"
            ),
        ]
    )
    func fewerMentionsPasses(
        locale: String,
        english: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: locale,
            english: english,
            value: value
        )
        #expect(result.status == 0)
    }

    /// The complementary half: presence is per **name**, so a value
    /// naming both bars must keep both. That is not branding, it is
    /// meaning — the real `bars.same_edge` string contrasts them
    /// ("Space Bar sits at the screen edge, App Bar sits next to
    /// the windows"), and a translation keeping one turns a
    /// contrast into a tautology. Softening the rule to "any one
    /// name is enough" would let that through.
    @Test("keeping only one of two names still fails")
    func keepingOnlyOneNameFails() throws {
        let result = try ProductNameFixture.check(
            locale: "de",
            english:
                "Space Bar sits at the edge, App Bar sits inside.",
            value:
                "Die Space Bar sitzt am Rand, die App-Leiste "
                + "sitzt innen."
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("App Bar"))
    }

    /// Capitalization is the locale's own business — a lower-cased
    /// "app bar" still names the thing, and flagging it would turn
    /// a style guide into a build failure.
    @Test("case differences are allowed")
    func caseInsensitive() throws {
        let result = try ProductNameFixture.check(
            locale: "de",
            english: "Show app bar",
            value: "App bar anzeigen"
        )
        #expect(result.status == 0)
    }

    /// The shape that nearly made this guard fight correct German.
    /// A compounding language hyphenates a two-word proper noun
    /// onto the following noun, so "Space-Bar-Farben" IS "Space Bar
    /// colors" with the name intact — a raw substring test rejects
    /// it and pushes the translator to the ungrammatical
    /// "Space Bar Farben". The non-breaking variants are the same
    /// class and travel invisibly through translation tools.
    @Test(
        "a compounded or NBSP-joined name still counts as kept",
        arguments: [
            ("Space Bar colors", "Space-Bar-Farben"),
            ("App Bar position", "App-Bar-Position"),
            ("App Bar style", "App\u{2011}Bar\u{2011}Stil"),
            ("Space Bar colors", "Space\u{00a0}Bar Farben"),
        ]
    )
    func compoundedNameIsKept(
        english: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: "de",
            english: english,
            value: value
        )
        #expect(result.status == 0)
    }

    /// And the normalisation must not have blunted the rule:
    /// hyphenating a *translated* stem is still a dropped name.
    @Test("compounding a translated stem still fails")
    func compoundedTranslationStillFails() throws {
        let result = try ProductNameFixture.check(
            locale: "de",
            english: "Space Bar colors",
            value: "Space-Leisten-Farben"
        )
        #expect(result.status != 0)
    }

    /// Script is irrelevant: a non-Latin locale must keep the name
    /// too. `bars.switch.space_bar` is Latin "Space Bar" in all
    /// eleven catalogs, so a Japanese sentence naming it
    /// スペースバー describes something the picker does not call
    /// that — the same defect as German's "App-Leiste", not a
    /// different case deserving a different rule.
    ///
    /// スペースバー and 스페이스바 make it worse than the Latin
    /// case rather than better: both are the ordinary words for
    /// the **spacebar key**, and neither script has capitalization
    /// to mark a proper noun, so the adapted name is
    /// indistinguishable from the key.
    ///
    /// Each value is written in its own locale's script, because
    /// the *script* guard runs in the same pass: one shared
    /// katakana fixture made this test fail for `ru`/`ko`/`zh-*` on
    /// foreign characters, which proves nothing about this rule.
    @Test(
        "a non-Latin locale must keep the name too",
        arguments: [
            ("ja", "スペースバーの色"),
            ("ko", "스페이스 바 색상"),
            ("ru", "Цвета панели пространств"),
            ("zh-Hans", "空间栏颜色"),
            ("zh-Hant", "空間列顏色"),
        ]
    )
    func nonLatinLocaleMustKeepName(
        locale: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: locale,
            english: "Space Bar colors",
            value: value
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("feature name"))
    }

    /// And the complement: a non-Latin locale that DOES keep the
    /// name verbatim inside its own script passes — the shape all
    /// five actually ship. Without this, the test above would be
    /// satisfied by a guard that simply failed every non-Latin
    /// value, which is a different bug with the same signature.
    @Test(
        "a non-Latin locale keeping the name passes",
        arguments: [
            ("ja", "Space Barの色"),
            ("ko", "Space Bar 색상"),
            ("ru", "Цвета Space Bar"),
            ("zh-Hans", "Space Bar 颜色"),
            ("zh-Hant", "Space Bar 顏色"),
        ]
    )
    func nonLatinLocaleKeepingNamePasses(
        locale: String,
        value: String
    ) throws {
        let result = try ProductNameFixture.check(
            locale: locale,
            english: "Space Bar colors",
            value: value
        )
        #expect(result.status == 0)
    }

    /// A key whose English never mentions a feature name cannot be
    /// flagged for omitting one.
    @Test("an unrelated string is untouched")
    func unrelatedStringPasses() throws {
        let result = try ProductNameFixture.check(
            locale: "de",
            english: "Outer gap",
            value: "Äußerer Abstand"
        )
        #expect(result.status == 0)
    }
}

/// Spawns `extract-keys --check` over a two-key temp tree: one
/// fixture string, one locale file. Mirrors `ResidueFixture`; the
/// shared script-spawn primitives come from `ScriptFixture`.
private enum ProductNameFixture {
    static func check(
        locale: String,
        english: String,
        value: String
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-product-name-\(UUID().uuidString)"
            )
        let sources = base.appendingPathComponent("Sources")
        let locales = base.appendingPathComponent("Locales")
        defer { try? FileManager.default.removeItem(at: base) }
        for directory in [sources, locales] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        let escaped =
            english
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        try "let _ = L(\"a.key\", \"\(escaped)\")".write(
            to: sources.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/extract-keys")
        var environment = ProcessInfo.processInfo.environment
        environment["KIWIDESK_EXTRACT_SOURCES"] = sources.path
        environment["KIWIDESK_EXTRACT_LOCALES"] = locales.path
        // Generate `en.json` first, so `--check` has an English
        // side to compare the locale value against.
        try runPythonScript(
            at: script,
            arguments: [],
            environment: environment
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(["a.key": value]).write(
            to:
                locales
                .appendingPathComponent("\(locale).json")
        )
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }
}
