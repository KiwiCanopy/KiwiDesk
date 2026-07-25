import Foundation
import Testing

/// Exercises `scripts/drop-key` (issue #249): dropping a key
/// whose English meaning changed must remove it from every
/// shipped translation, never touch the generated en.json, and
/// reject keys present nowhere (typo guard) without touching
/// any file.
@Suite("drop-key")
struct DropKeyTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// `drop-key` derives its repo root from `__file__`, so the
    /// shared `ScriptFixture` primitives copy it into a fixture
    /// tree shaped like the real repo.
    private func makeFixtureRoot(
        locales localeFiles: [String: String]
    ) throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-drop-key",
            locales: localeFiles
        )
    }

    @discardableResult
    private func run(
        _ arguments: [String],
        fixture: RepoShapedFixture
    ) throws -> ScriptRun {
        try runRepoScript(
            "drop-key",
            arguments: arguments,
            in: fixture,
            repoRoot: repoRoot
        )
    }

    @Test("drops from every translation, never from en.json")
    func dropsFromTranslationsNotEnglish() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"gap.hint": "New meaning", "menu.quit": "Quit"}
            """#,
            "de.json": #"""
            {"gap.hint": "Alte Bedeutung", "menu.quit": "Ende"}
            """#,
            "fr.json": #"""
            {"gap.hint": "Vieux sens"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(["gap.hint"], fixture: fixture)
        #expect(result.status == 0)

        let en = try fixture.decodeLocale("en.json")
        #expect(en["gap.hint"] == "New meaning")
        let de = try fixture.decodeLocale("de.json")
        #expect(de == ["menu.quit": "Ende"])
        let fr = try fixture.decodeLocale("fr.json")
        #expect(fr == [:])
    }

    @Test("fails atomically when any key exists nowhere")
    func failsAtomicallyOnUnknownKey() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"gap.hint": "New meaning"}
            """#,
            "de.json": #"""
            {"gap.hint": "Alte Bedeutung"}
            """#,
        ])
        defer { fixture.cleanup() }
        // gap.hint exists in de; no.such.key nowhere — the
        // batch must fail without dropping gap.hint.
        let result = try run(
            ["gap.hint", "no.such.key"],
            fixture: fixture
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("no.such.key"))
        let de = try fixture.decodeLocale("de.json")
        #expect(de["gap.hint"] == "Alte Bedeutung")
    }

    @Test("key present only in en.json counts as nowhere")
    func englishOnlyKeyIsRejected() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"fresh.key": "Brand new"}
            """#,
            "de.json": #"""
            {"menu.quit": "Ende"}
            """#,
        ])
        defer { fixture.cleanup() }
        // A brand-new key has no stale translations to drop —
        // treat as a mistake, not a no-op success.
        let result = try run(["fresh.key"], fixture: fixture)
        #expect(result.status != 0)
        #expect(result.stderr.contains("fresh.key"))
    }

    @Test("a key repeated in argv drops once, no crash")
    func duplicateArgvKeyIsDeduplicated() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"a.key": "A", "b.key": "B"}
            """#,
            "de.json": #"""
            {"b.key": "Be"}
            """#,
            "fr.json": #"""
            {"a.key": "Ah"}
            """#,
        ])
        defer { fixture.cleanup() }
        // de (sorted first) holds only b.key; a repeated a.key
        // must not crash after de was already written.
        let result = try run(
            ["a.key", "a.key", "b.key"],
            fixture: fixture
        )
        #expect(result.status == 0)
        let de = try fixture.decodeLocale("de.json")
        #expect(de == [:])
        let fr = try fixture.decodeLocale("fr.json")
        #expect(fr == [:])
    }

    @Test("drops multiple keys, including empty-string values")
    func dropsMultipleKeysAndEmptyValues() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"a.key": "A", "b.key": "B"}
            """#,
            "de.json": #"""
            {"a.key": "", "b.key": "Be", "menu.quit": "Ende"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["a.key", "b.key"],
            fixture: fixture
        )
        #expect(result.status == 0)
        let de = try fixture.decodeLocale("de.json")
        #expect(de == ["menu.quit": "Ende"])
    }
}
