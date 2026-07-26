import Foundation
import Testing

/// Exercises the *exact* per-value content guards `extract-keys
/// --check` gates on (issue #95): a wrong writing system, a tagged
/// English stub, and interpolation-specifier drift. The heuristic
/// one lives in `LocalizationResidueGuardTests`, and the two
/// corpus-wide checks in `LocalizationOverlapGuardTests` and
/// `LocalizationCollapseGuardTests`.
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
        // Not just "some failure": a bare non-zero exit is also
        // what a traceback or a different guard would produce.
        if !passes {
            #expect(result.stderr.contains("Kana"))
        }
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

    /// Placeholder parity is the one guard protecting a *runtime*
    /// path: these values reach `String(format:)`, so a dropped
    /// `%1$@` loses the interpolated name and an invented one reads
    /// an argument that was never passed.
    @Test(
        "specifier drift fails",
        arguments: [
            ("About %1$@", "情報", "drops"),
            ("About %1$@", "%1$@ の %2$@ について", "adds"),
        ]
    )
    func specifierDriftFails(
        english: String,
        value: String,
        verb: String
    ) throws {
        let result = try ContentGuardFixture.check(
            english: ["a.about": english],
            catalogs: ["ja": ["a.about": value]]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains(verb))
    }

    /// The numbering exists so a translation *can* reorder the
    /// arguments, and many languages must — so order is not drift.
    @Test("reordered specifiers pass")
    func reorderedSpecifiersPass() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.two": "%1$@ before %2$@"],
            catalogs: ["ja": ["a.two": "%2$@ の前に %1$@"]]
        )
        #expect(result.status == 0)
    }

    /// `%%` renders a literal percent and carries no argument, so a
    /// translation may add it — several locales write `"%1$d%%"`
    /// where the English spells out "percent".
    @Test("a literal percent is not drift")
    func literalPercentIsNotDrift() throws {
        let result = try ContentGuardFixture.check(
            english: ["a.pct": "ratio %1$d percent"],
            catalogs: ["ja": ["a.pct": "比率 %1$d%%"]]
        )
        #expect(result.status == 0)
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
        // Inherit the real environment and override the two keys,
        // rather than replacing it. A two-entry environment drops
        // PATH, so `/usr/bin/env python3` fell back to the system
        // 3.9 — a different interpreter from the one
        // `scripts/lint.sh` and CI use, which quietly made the
        // suite the only thing pinning 3.9 compatibility.
        var environment = ProcessInfo.processInfo.environment
        environment["KIWIDESK_EXTRACT_SOURCES"] = sources.path
        environment["KIWIDESK_EXTRACT_LOCALES"] = locales.path
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
