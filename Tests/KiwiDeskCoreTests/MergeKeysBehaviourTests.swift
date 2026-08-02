import Foundation
import Testing

/// `scripts/merge-keys` behaviour that is *not* the #252
/// stale-source guard: the pre-existing empty-translation and
/// missing-worksheet paths the guard must not have broken, the
/// malformed-input paths, and `--site`.
///
/// Split from `MergeKeysTests` at the 350-line ceiling (AGENTS.md
/// §2.1, §5 "split test suites early"); the guard's own cases
/// live there. Per-file private helpers are the convention, so
/// the small fixture/run pair below is duplicated deliberately —
/// only the spawn primitives are shared (`ScriptFixture.swift`).
///
/// Note for a future cleanup: `siteModeUsesSiteDirectory` below
/// is the **only** `--site` coverage in the whole test tree
/// (`extract-keys --site` is unreachable under its env-var test
/// shape), so it is not redundant with anything.
@Suite("merge-keys behaviour")
struct MergeKeysBehaviourTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func fixture(
        locales: [String: String],
        siteLocales: [String: String] = [:]
    ) throws -> RepoShapedFixture {
        try makeRepoShapedFixture(
            prefix: "kiwi-merge-keys-behaviour",
            locales: locales,
            siteLocales: siteLocales
        )
    }

    @discardableResult
    private func run(
        _ arguments: [String],
        in fixture: RepoShapedFixture
    ) throws -> ScriptRun {
        try runRepoScript(
            "merge-keys",
            arguments: arguments,
            in: fixture,
            repoRoot: repoRoot
        )
    }

    // MARK: - Malformed input reports, never crashes

    @Test("a bare-string entry is dropped, and its text echoed")
    func bareStringEntryIsEchoedNotSwallowed() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"a.key": "A"}"#,
            "de.json": #"{}"#,
            // Not the {"source", "translation"} shape at all —
            // the likeliest hand-written worksheet. It cannot be
            // verified, so it is dropped; but the worksheet is
            // unlinked either way, so the stderr transcript is
            // the only surviving copy of the text and MUST carry
            // it. Echoing '' here would quietly lose the work.
            "missing_de.json": #"{"a.key": "Ein wichtiger Text"}"#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
        #expect(result.stderr.contains("Ein wichtiger Text"))
    }

    @Test("a non-string translation is unverifiable, not empty")
    func nonStringTranslationIsNotReportedAsEmpty() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"a.key": "A"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"a.key": {"source": "A", "translation": 5}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
        // Malformed, not blank — saying "still had an empty
        // translation" would send the translator looking for
        // work they already did.
        #expect(!result.stdout.contains("empty"))
        #expect(result.stderr.contains("a.key"))
    }

    @Test("a non-UTF-8 worksheet reports, it does not traceback")
    func nonUtf8WorksheetIsReported() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"a.key": "A"}"#,
            "de.json": #"{}"#,
        ])
        defer { fx.cleanup() }
        // A translator's editor saving as Latin-1 is the one
        // realistic non-UTF-8 source in this pipeline.
        let latin1 =
            #"{"a.key": {"source": "A", "#
            + #""translation": "gr\#u{00FC}n"}}"#
        try FileManager.default.createDirectory(
            at: fx.worksheets,
            withIntermediateDirectories: true
        )
        try Data(latin1.compactMap { $0.asciiValue ?? 0xFC })
            .write(
                to: fx.worksheets.appendingPathComponent(
                    "missing_de.json"
                )
            )

        let result = try run(["de"], in: fx)
        #expect(result.status != 0)
        #expect(!result.stderr.contains("Traceback"))
        #expect(result.stderr.contains("merge-keys:"))
        // Nothing merged, worksheet kept for a second attempt.
        #expect(fx.localeFileExists("missing_de.json"))
    }

    @Test("a malformed en.json reports, it does not traceback")
    func malformedEnglishIsReported() throws {
        let fx = try fixture(locales: [
            "en.json": #"{not json"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"a.key": {"source": "A", "translation": "Ah"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status != 0)
        #expect(!result.stderr.contains("Traceback"))
        #expect(result.stderr.contains("en.json"))
        #expect(fx.localeFileExists("missing_de.json"))
    }

    // MARK: - Pre-existing behaviour the guard must not break

    @Test("an empty translation is still skipped, not merged")
    func skipsEmptyTranslation() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Meaning"}"#,
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Meaning",
                          "translation": "   "}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json").isEmpty)
        #expect(result.stdout.contains("gap.hint"))
    }

    @Test("fails when the worksheet does not exist")
    func failsWithoutWorksheet() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Meaning"}"#
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status != 0)
        #expect(result.stderr.contains("extract-keys"))
    }

    @Test("fails when en.json is absent — nothing is verifiable")
    func failsWithoutEnglish() throws {
        let fx = try fixture(locales: [
            "de.json": #"{}"#,
            "missing_de.json": #"""
            {"gap.hint": {"source": "Meaning",
                          "translation": "Bedeutung"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["de"], in: fx)
        #expect(result.status != 0)
        // Refusing beats merging data no guard could check.
        #expect(fx.localeFileExists("missing_de.json"))
        #expect(try fx.decodeLocale("de.json").isEmpty)
    }

    @Test("creates the locale file when it does not exist yet")
    func createsMissingLocaleFile() throws {
        let fx = try fixture(locales: [
            "en.json": #"{"gap.hint": "Meaning"}"#,
            "missing_fr.json": #"""
            {"gap.hint": {"source": "Meaning",
                          "translation": "Sens"}}
            """#,
        ])
        defer { fx.cleanup() }

        let result = try run(["fr"], in: fx)
        #expect(result.status == 0)
        #expect(
            try fx.decodeLocale("fr.json") == [
                "gap.hint": "Sens"
            ]
        )
    }

    // MARK: - `--site`

    @Test("--site reads and writes the site manifests")
    func siteModeUsesSiteDirectory() throws {
        let fx = try fixture(
            // The app tree holds a *different* English for the
            // same key, so passing --site against it would show
            // up as a stale skip rather than a silent pass.
            locales: [
                "en.json": #"{"hero.title": "App English"}"#
            ],
            siteLocales: [
                "en.json": #"{"hero.title": "Site English"}"#,
                "de.json": #"{}"#,
                "missing_de.json": #"""
                {"hero.title": {"source": "Site English",
                                "translation": "Seitentitel"}}
                """#,
            ]
        )
        defer { fx.cleanup() }

        let result = try run(["--site", "de"], in: fx)
        #expect(result.status == 0)
        #expect(
            try fx.decodeLocale("de.json", site: true) == [
                "hero.title": "Seitentitel"
            ]
        )
        // The app tree must be untouched.
        #expect(!fx.localeFileExists("de.json"))
    }

    @Test("--site applies the stale-source guard too")
    func siteModeGuardsStaleSource() throws {
        let fx = try fixture(
            locales: ["en.json": #"{"hero.title": "Whatever"}"#],
            siteLocales: [
                "en.json": #"{"hero.title": "New site copy"}"#,
                "de.json": #"{}"#,
                "missing_de.json": #"""
                {"hero.title": {"source": "Old site copy",
                                "translation": "Alt"}}
                """#,
            ]
        )
        defer { fx.cleanup() }

        let result = try run(["--site", "de"], in: fx)
        #expect(result.status == 0)
        #expect(try fx.decodeLocale("de.json", site: true).isEmpty)
        #expect(result.stderr.contains("hero.title"))
        #expect(result.stderr.contains("--site"))
    }
}
