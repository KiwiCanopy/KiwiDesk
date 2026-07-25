import Foundation
import Testing

/// Exercises `scripts/rename-key` (issue #9 review): a pure key
/// rename must preserve every locale's existing translation
/// value, and must reject a missing source key or a colliding
/// destination key rather than silently clobbering data.
@Suite("rename-key")
struct RenameKeyTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// `rename-key` has no env-var override (it always targets
    /// `Sources/KiwiDeskCore/Resources/Locales` under its own
    /// `__file__`-derived repo root) — so the shared
    /// `ScriptFixture` primitives copy the script into a fixture
    /// tree shaped like the real repo and run it there.
    private func makeFixtureRoot(
        locales localeFiles: [String: String]
    ) throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-rename-key",
            locales: localeFiles
        )
    }

    @discardableResult
    private func run(
        _ arguments: [String],
        fixture: RepoShapedFixture
    ) throws -> ScriptRun {
        try runRepoScript(
            "rename-key",
            arguments: arguments,
            in: fixture,
            repoRoot: repoRoot
        )
    }

    @Test("renames the key in every locale file, keeping values")
    func renamesAcrossAllLocalesPreservingValues() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#,
            "de.json": #"""
            {"menu.quit": "KiwiDesk beenden"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            fixture: fixture
        )
        #expect(result.status == 0)

        for (name, expected) in [
            ("en.json", "Quit KiwiDesk"),
            ("de.json", "KiwiDesk beenden"),
        ] {
            let decoded = try fixture.decodeLocale(name)
            #expect(decoded["menu.quit"] == nil)
            #expect(decoded["menu.exit"] == expected)
        }
    }

    @Test("fails when the old key is absent everywhere")
    func failsWhenOldKeyMissing() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["no.such.key", "some.new.key"],
            fixture: fixture
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("no.such.key"))
    }

    @Test("fails when the new key already exists")
    func failsWhenNewKeyCollides() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk",
             "menu.exit": "Already taken"}
            """#
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            fixture: fixture
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("menu.exit"))

        // Nothing was touched on failure.
        let decoded = try fixture.decodeLocale("en.json")
        #expect(decoded["menu.quit"] == "Quit KiwiDesk")
        #expect(decoded["menu.exit"] == "Already taken")
    }

    @Test("only renames in locales that actually have the key")
    func onlyTouchesLocalesThatHaveTheKey() throws {
        let fixture = try makeFixtureRoot(locales: [
            "en.json": #"""
            {"menu.quit": "Quit KiwiDesk"}
            """#,
            "fr.json": #"""
            {"menu.settings": "Réglages…"}
            """#,
        ])
        defer { fixture.cleanup() }
        let result = try run(
            ["menu.quit", "menu.exit"],
            fixture: fixture
        )
        #expect(result.status == 0)

        let fr = try fixture.decodeLocale("fr.json")
        // fr.json never had menu.quit — untouched, no
        // spurious menu.exit key created.
        #expect(fr == ["menu.settings": "Réglages…"])
    }
}
