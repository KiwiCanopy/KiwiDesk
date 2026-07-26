import Foundation
import Testing

/// Exercises the English-residue guard (issue #95) — the one
/// *heuristic* among the content guards, and the only one with a
/// scope: non-Latin-script locales.
///
/// Split from `LocalizationContentGuardTests` (which keeps the
/// exact per-value contracts: script, stub, placeholder) because
/// the combined file passed the 350-line ceiling §5 names for test
/// suites, and because the scope argument here needs room to be
/// pinned from both sides — it must fire, and it must stay off
/// where a retained word is a cognate.
///
/// Fixtures are text the test writes itself, never the shipped
/// catalogs.
@Suite("extract-keys residue guard")
struct LocalizationResidueGuardTests {
    @Test(
        "English left in a non-Latin value fails",
        arguments: [
            ("ja", "追加 Window", "Add Window"),
            ("ko", "추가 a mode", "Add a mode"),
            ("zh-Hans", "焦点 anchor", "Focus anchor"),
            ("zh-Hant", "焦點 anchor", "Focus anchor"),
            ("ru", "Фокус here", "Focus here"),
        ]
    )
    func residueFails(
        locale: String,
        value: String,
        english: String
    ) throws {
        let result = try ResidueFixture.check(
            locale: locale,
            english: english,
            value: value
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("English word"))
    }

    /// The scope, pinned from the other side. All three are correct
    /// translations, and a rule that read a retained English word
    /// as residue here would flag good work by the dozen: `item`,
    /// `Setup` and `track` are a cognate, a loanword and a
    /// technical term.
    @Test(
        "a Latin-script cognate is not residue",
        arguments: [
            ("pt-BR", "Active item", "Item ativo"),
            ("de", "My Setup", "Mein Setup"),
            ("it", "Track limit", "Limite del track"),
            ("es", "Focus mode", "Modo focus"),
        ]
    )
    func latinCognateIsNotResidue(
        locale: String,
        english: String,
        value: String
    ) throws {
        let result = try ResidueFixture.check(
            locale: locale,
            english: english,
            value: value
        )
        #expect(result.status == 0)
    }

    /// A weld — an English suffix fused to a translated stem,
    /// `"編集ing"`, `"保存d profiles"` — is caught by the rule above
    /// rather than by a rule of its own. An earlier draft had one,
    /// justified as "no target language forms a word that way";
    /// German falsifies that (`fing`, `ging`, `Frühling`), and
    /// scoping it to non-Latin locales made it unreachable, because
    /// the stem there is non-Latin and tokenizing leaves a bare
    /// suffix. So this value must fail on `directly`, not on the
    /// weld.
    @Test("a weld is caught by the retained word beside it")
    func weldIsCaughtByRetainedWord() throws {
        let result = try ResidueFixture.check(
            locale: "ja",
            english: "Editing init.lua directly.",
            value: "編集ing init.lua directly."
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("directly"))
    }

    /// The corollary, stated so nobody re-adds the weld rule
    /// expecting this to fail: a weld with *nothing* English beside
    /// it is not caught, in any locale. It is the documented gap.
    @Test("a bare weld is not caught")
    func bareWeldIsNotCaught() throws {
        let result = try ResidueFixture.check(
            locale: "ja",
            english: "Editing",
            value: "編集ing"
        )
        #expect(result.status == 0)
    }

    @Test("an all-English value is not read as residue")
    func untranslatedValueIsNotResidue() throws {
        // A different defect, and one no guard owns — correct for
        // the keys whose English is a bare product term.
        let result = try ResidueFixture.check(
            locale: "ja",
            english: "Lua",
            value: "Lua"
        )
        #expect(result.status == 0)
    }

    @Test(
        "glossary terms and stripped tokens survive translation",
        arguments: [
            ("Show app bar", "App Barを表示"),
            ("Mission Control: Space Left", "Mission Control: 左"),
            ("Edit init.lua", "init.luaを編集"),
            ("%1$d screens", "画面%1$d台"),
            ("Press ⌘ Command", "⌘ Commandを押す"),
            ("Collapse into a +n badge", "+n バッジに折りたたむ"),
            ("Stack preview: %1$d windows", "Stack プレビュー %1$d"),
            ("Bundle identifier", "Bundle 識別子"),
        ]
    )
    func glossaryIsNotResidue(
        english: String,
        value: String
    ) throws {
        let result = try ResidueFixture.check(
            locale: "ja",
            english: english,
            value: value
        )
        #expect(result.status == 0)
    }

    /// `Command` is stripped only where a modifier glyph precedes
    /// it, so the same word left bare is still caught — the reason
    /// the key names are stripped rather than glossarised.
    @Test("a bare key name is still residue")
    func bareKeyNameIsResidue() throws {
        let result = try ResidueFixture.check(
            locale: "ja",
            english: "Command Center",
            value: "Command 中央"
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("Command"))
    }
}

/// Runs the real `scripts/extract-keys --check` over a single
/// key in a single locale — all this suite ever needs.
private enum ResidueFixture {
    static func check(
        locale: String,
        english: String,
        value: String
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-residue-guard-\(UUID().uuidString)"
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
