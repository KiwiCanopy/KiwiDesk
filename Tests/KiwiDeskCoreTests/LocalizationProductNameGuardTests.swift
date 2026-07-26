import Foundation
import Testing

/// Exercises the dropped-feature-name guard: the GUI ships
/// "App Bar" and "Space Bar" untranslated, so a Latin-script
/// locale must carry them verbatim (owner call, 2026-07-27).
///
/// The mirror image of the residue guard, and scoped to the
/// complementary set of locales — so the two are pinned from
/// opposite sides and neither can quietly widen into the other's
/// territory. `GLOSSARY` already *exempted* these words from
/// residue; nothing checked that anyone kept them, and `de` had
/// rendered all 25 of its occurrences as "App-Leiste" /
/// "Space-Leiste".
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

    /// The scope, pinned from the other side. A non-Latin sentence
    /// carries the phrase as a foreign body, so adapting it is a
    /// real editorial choice the owner explicitly allowed — and if
    /// this ever starts failing, the guard has swallowed the
    /// residue guard's territory.
    ///
    /// Each value is written in its own locale's script, because
    /// the *script* guard runs in the same pass: one shared
    /// katakana fixture made this test fail for `ru`/`ko`/`zh-*` on
    /// foreign characters, which proves nothing about this rule.
    @Test(
        "a non-Latin locale may adapt the name",
        arguments: [
            ("ja", "スペースバーの色"),
            ("ko", "스페이스 바 색상"),
            ("ru", "Цвета панели пространств"),
            ("zh-Hans", "空间栏颜色"),
            ("zh-Hant", "空間列顏色"),
        ]
    )
    func nonLatinLocaleMayAdapt(
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
