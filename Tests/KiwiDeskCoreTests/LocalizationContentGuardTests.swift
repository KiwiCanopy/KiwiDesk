import Foundation
import Testing

/// Exercises the per-value content guards `extract-keys --check`
/// gates on (issue #95): a wrong writing system, a tagged English
/// stub, and English words left inside a translated sentence.
/// `LocalizationOverlapGuardTests` covers the corpus-wide
/// cross-language check that needs whole catalogs.
///
/// Every fixture is text the test writes itself. Asserting against
/// the shipped catalogs instead would tie the guard's coverage to
/// the corpus staying dirty — each assertion would pass only while
/// a real bug was live and fail the moment it was fixed.
@Suite("extract-keys content guards")
struct LocalizationContentGuardTests {
    @Test("a clean catalog exits 0")
    func cleanCatalogPasses() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.save": "Save copy"],
            catalogs: ["ja": ["a.save": "コピーを保存"]]
        )
        #expect(result.status == 0)
    }

    @Test("Cyrillic in a Japanese value fails")
    func cyrillicInJapaneseFails() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.focus": "Focus here"],
            catalogs: ["ja": ["a.focus": "Фокус здесь"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("Cyrillic"))
        #expect(result.stderr.contains("a.focus"))
    }

    @Test("Cyrillic is Russian's own script")
    func cyrillicInRussianPasses() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.focus": "Focus here"],
            catalogs: ["ru": ["a.focus": "Фокус здесь"]]
        )
        #expect(result.status == 0)
    }

    /// Han cannot separate Japanese from either Chinese script, so
    /// the table lists it for all three; kana can, because Chinese
    /// has none.
    @Test(
        "Han is shared, kana is not",
        arguments: [
            ("ja", "ウインドウを追加", true),
            ("zh-Hans", "添加窗口", true),
            ("zh-Hant", "新增視窗", true),
            ("zh-Hans", "ウインドウを追加", false),
            ("zh-Hant", "ウインドウを追加", false),
        ]
    )
    func hanAndKanaAttribution(
        locale: String,
        value: String,
        passes: Bool
    ) throws {
        let result = try ContentGuardFixture.check(
            english: ["a.add": "Add window"],
            catalogs: [locale: ["a.add": value]]
        )
        #expect((result.status == 0) == passes)
    }

    @Test("Hangul outside Korean fails")
    func hangulOutsideKoreanFails() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.add": "Add window"],
            catalogs: ["ja": ["a.add": "윈도우 추가"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("Hangul"))
    }

    /// Latin is deliberately absent from the table: every locale
    /// uses it for the product name, URLs and `%1$@`, so its
    /// presence proves nothing.
    @Test("Latin is never foreign to any locale")
    func latinIsNeverForeign() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.name": "KiwiDesk"],
            catalogs: [
                "ja": ["a.name": "KiwiDesk"],
                "ru": ["a.name": "KiwiDesk"],
                "ko": ["a.name": "KiwiDesk"],
            ]
        )
        #expect(result.status == 0)
    }

    @Test("a generated en.json is script-checked too")
    func englishIsScriptChecked() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.oops": "Save 保存"],
            catalogs: [:]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("en.json"))
        #expect(result.stderr.contains("Han"))
    }

    @Test("a tagged stub fails")
    func taggedStubFails() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.icon": "Icon & name"],
            catalogs: ["es": ["a.icon": "Icon & name (ES)"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("tagged stub"))
    }

    /// The full-width paren pair is why an ASCII-only regex once
    /// reported a 45%-complete Japanese file as 98% complete.
    @Test("a full-width tagged stub fails")
    func fullWidthTaggedStubFails() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.group": "Group adjacent…"],
            catalogs: ["ja": ["a.group": "Group adjacent…（JA）"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("tagged stub"))
    }

    @Test("a base-language tag catches a regional locale")
    func baseLanguageTagIsAStub() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.item": "Item"],
            catalogs: ["pt-BR": ["a.item": "Item (PT)"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("tagged stub"))
    }

    /// A value naming a *different* language is a legitimate
    /// string, not a stub marker.
    @Test("another language's tag is not a stub")
    func foreignLocaleTagIsNotAStub() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.lang": "German (DE)"],
            catalogs: ["es": ["a.lang": "Alemán (DE)"]]
        )
        #expect(result.status == 0)
    }

    @Test(
        "English left in a non-Latin value fails",
        arguments: [
            ("ja", "追加 Window", "Window"),
            ("ko", "추가 a mode", "a"),
            ("zh-Hans", "焦点 anchor", "anchor"),
            ("ru", "Фокус here", "here"),
        ]
    )
    func englishResidueFails(
        locale: String,
        value: String,
        word: String
    ) throws {
        let english = [
            "Window": "Add Window",
            "a": "Add a mode",
            "anchor": "Focus anchor",
            "here": "Focus here",
        ][word]!
        let result = try ContentGuardFixture.check(
            english: ["a.key": english],
            catalogs: [locale: ["a.key": value]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("English word"))
    }

    /// The residue rule is confined to non-Latin scripts on
    /// purpose: in a Latin-script locale a retained English word is
    /// indistinguishable from a cognate or a loanword, and these
    /// three are all correct translations.
    @Test(
        "a Latin-script cognate is not residue",
        arguments: [
            ("pt-BR", "Active item", "Item ativo"),
            ("de", "My Setup", "Mein Setup"),
            ("it", "Track limit", "Limite del track"),
        ]
    )
    func latinCognateIsNotResidue(
        locale: String,
        english: String,
        value: String
    ) throws {
        let result = try ContentGuardFixture.check(
            english: ["a.key": english],
            catalogs: [locale: ["a.key": value]]
        )
        #expect(result.status == 0)
    }

    /// An English `-ing` welded onto a translated stem is precise
    /// in *any* locale — no target language forms a word that way.
    @Test("a welded English gerund fails in a Latin locale")
    func weldedGerundFails() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.edit": "Editing init.lua directly."],
            catalogs: ["fr": ["a.edit": "Modifiering init.lua."]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("Modifiering"))
    }

    @Test("an all-English value is not read as residue")
    func untranslatedValueIsNotResidue() throws {
        // A different defect with a different fix, and correct for
        // the handful of keys whose English is a bare product term.
        let result = try ContentGuardFixture.check(
            english: ["a.lua": "Lua"],
            catalogs: ["ja": ["a.lua": "Lua"]]
        )
        #expect(result.status == 0)
    }

    @Test(
        "glossary terms and specifiers survive translation",
        arguments: [
            ("Show app bar", "App Barを表示"),
            ("Mission Control: Space Left", "Mission Control: 左"),
            ("Edit init.lua", "init.luaを編集"),
            ("%1$d screens", "画面%1$d台"),
            ("Press ⌘ Command", "⌘ Commandを押す"),
            ("Collapse into a +n badge", "+n バッジに折りたたむ"),
        ]
    )
    func glossaryIsNotResidue(
        english: String,
        value: String
    ) throws {
        let result = try ContentGuardFixture.check(
            english: ["a.key": english],
            catalogs: ["ja": ["a.key": value]]
        )
        #expect(result.status == 0)
    }

    /// `Command` is stripped only where a modifier glyph precedes
    /// it, so the same word left bare is still caught — the reason
    /// the key names are stripped rather than glossarised.
    @Test("a bare key name is still residue")
    func bareKeyNameIsResidue() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.preset": "Command Center"],
            catalogs: ["ja": ["a.preset": "Command 中央"]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("Command"))
    }
}

/// Runs the real `scripts/extract-keys --check` against a
/// throwaway tree, via the `KIWIDESK_EXTRACT_*` overrides (the
/// env-var-scoped shape described in `ScriptFixture.swift`).
///
/// `english` becomes the `L(...)` call sites, so the generated
/// `en.json` is fresh by construction and `--check` can only fail
/// on the content guards — never on staleness.
private enum ContentGuardFixture {
    static func check(
        english: [String: String],
        catalogs: [String: [String: String]]
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-content-guard-\(UUID().uuidString)"
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
        try callSites(english).write(
            to: sources.appendingPathComponent("Fixture.swift"),
            atomically: true,
            encoding: .utf8
        )
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/extract-keys")
        let environment = [
            "KIWIDESK_EXTRACT_SOURCES": sources.path,
            "KIWIDESK_EXTRACT_LOCALES": locales.path,
        ]
        // Generate en.json first: `--check` compares against it,
        // and a fixture that skipped this step would fail as
        // stale whatever the catalogs contained.
        try runPythonScript(
            at: script,
            arguments: [],
            environment: environment
        )
        for (locale, catalog) in catalogs {
            try write(
                catalog,
                to:
                    locales
                    .appendingPathComponent("\(locale).json")
            )
        }
        return try runPythonScript(
            at: script,
            arguments: ["--check"],
            environment: environment
        )
    }

    /// One `L(key, english)` per entry, sorted so the generated
    /// source is stable.
    private static func callSites(
        _ english: [String: String]
    ) -> String {
        english.sorted { $0.key < $1.key }
            .map { key, text in
                "let _ = L(\(quoted(key)), \(quoted(text)))"
            }
            .joined(separator: "\n")
    }

    /// Escapes the three characters that would otherwise break the
    /// generated Swift literal. `extract-keys` decodes the same
    /// three, so a fixture round-trips.
    private static func quoted(_ text: String) -> String {
        let escaped =
            text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "\"\(escaped)\""
    }

    private static func write(
        _ catalog: [String: String],
        to url: URL
    ) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(catalog).write(to: url)
    }
}
