import Foundation
import Testing

/// The other half of the worksheet invariant: a
/// `missing_<locale>.json` that turns up among the catalogs is
/// *rejected*, never skipped. `LocaleWorksheetLocationTests` owns
/// where `scripts/extract-keys` writes one; this suite owns what
/// happens when one is nonetheless there.
///
/// Split from that file at the 350-line ceiling (AGENTS.md §2.1,
/// `.claude/rules/tests.md` "split suites early"). Per-file
/// private helpers are the convention, so the fixture harness at
/// the bottom is deliberately its own copy — only the spawn
/// primitives are shared (`ScriptFixture.swift`).
///
/// Skipping is what the fix had to avoid: every walker in
/// `scripts/extract-keys` already filters `missing_*` by name, so
/// deleting the rejection would not fail anything — it would
/// simply make a misplaced worksheet invisible again, which is
/// how one came to surface as a `DecodingError` naming an
/// unrelated key.
@Suite("locale worksheet rejection")
struct LocaleWorksheetRejectionTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    @Test("--check rejects a worksheet left in Locales")
    func checkRejectsAWorksheetInTheCatalogDirectory() throws {
        let result = try runCheck(
            locales: [
                "en.json": #"{"gap.hint": "Gap between windows"}"#,
                "de.json": #"{"gap.hint": "Abstand"}"#,
                "missing_de.json": #"""
                {"gap.hint": {"source": "Gap between windows",
                              "translation": ""}}
                """#,
            ]
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("missing_de.json"))
        #expect(result.stderr.contains("worksheet"))
        #expect(
            result.stderr.contains("locale-worksheets/"),
            "the diagnosis must say where worksheets belong"
        )
    }

    /// The same corpus without the worksheet passes, so the test
    /// above reds for the worksheet and not for the fixture.
    @Test("--check passes on the same corpus without one")
    func checkPassesWithoutTheWorksheet() throws {
        let result = try runCheck(
            locales: [
                "en.json": #"{"gap.hint": "Gap between windows"}"#,
                "de.json": #"{"gap.hint": "Abstand"}"#,
            ]
        )
        #expect(result.status == 0)
    }

    /// And rejecting by name did not replace the shape check it
    /// sits in front of: a genuinely malformed *catalog* — the
    /// defect that makes `LocaleCatalog` soft-fail to `[:]` and a
    /// locale silently revert to English — must still hard-fail.
    @Test("--check still rejects a malformed catalog")
    func checkStillRejectsAMalformedCatalog() throws {
        let result = try runCheck(
            locales: [
                "en.json": #"{"gap.hint": "Gap between windows"}"#,
                "de.json": #"""
                {"gap.hint": {"nested": "Abstand"}}
                """#,
            ]
        )
        #expect(result.status != 0)
        // A traceback also exits non-zero. Gutting the shape
        // check made `check_content` fall over a dict value
        // instead of diagnosing it, which a bare status check
        // would have read as a healthy rejection.
        #expect(!result.stderr.contains("Traceback"))
        // The needle is the PER-FILE diagnosis, not the shared
        // header: the header prints whenever the malformed block
        // prints at all, so a needle it satisfies pins "something
        // was reported" rather than "the shape was explained".
        #expect(
            result.stderr.contains("de.json: non-string value")
        )
    }

    /// `--prune` is the one mode that *rewrites* every catalog,
    /// and it walks the name-filtered `shipped_locale_files()` —
    /// so without its own validation it would tidy the whole
    /// directory around a worksheet and report success. The
    /// unchanged `de.json` is the half that matters: refusing
    /// late, after the rewrite, would read the same on stderr.
    @Test("--prune refuses to rewrite around a worksheet")
    func pruneRejectsAWorksheetInTheCatalogDirectory() throws {
        var after: [String: String] = [:]
        let result = try runExtract(
            ["--prune"],
            locales: [
                "en.json": #"{"gap.hint": "Gap between windows"}"#,
                "de.json": #"""
                {"gap.hint": "Abstand", "gone.key": "Weg"}
                """#,
                "missing_de.json": #"""
                {"gap.hint": {"source": "Gap between windows",
                              "translation": ""}}
                """#,
            ],
            inspecting: { directory in
                after = try JSONDecoder().decode(
                    [String: String].self,
                    from: Data(
                        contentsOf:
                            directory
                            .appendingPathComponent("de.json")
                    )
                )
            }
        )
        #expect(result.status != 0)
        #expect(result.stderr.contains("missing_de.json"))
        // `gone.key` is a genuine orphan: a prune that ran would
        // have removed it.
        #expect(after["gone.key"] == "Weg")
    }

    /// The override redirects the worksheet tree and nothing
    /// redirects `site/src/i18n`, so a `--site` run under it
    /// would read — and `--prune` would rewrite — the developer's
    /// real site catalogs while writing worksheets to a temp
    /// directory. Half a redirect is worse than none, so both
    /// scripts refuse the combination before touching a path.
    @Test(
        "--site refuses to run under the worksheet override",
        arguments: ["extract-keys", "merge-keys"]
    )
    func siteRefusesUnderTheOverride(script: String) throws {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-worksheet-site-\(UUID().uuidString)"
            )
        defer { try? FileManager.default.removeItem(at: base) }
        let result = try runPythonScript(
            at: repoRoot.appendingPathComponent("scripts/\(script)"),
            arguments: ["--site", "de"],
            environment: [
                "KIWIDESK_EXTRACT_WORKSHEETS": base.path
            ]
        )
        #expect(result.status != 0)
        #expect(
            result.stderr.contains("KIWIDESK_EXTRACT_WORKSHEETS")
        )
        // Not the rooted `site/…` form: `CiPathFilterTests` reads
        // that literal in a test source as this suite reading the
        // real site tree, and it is right to — the needle only
        // needs to prove the message names the site catalogs.
        #expect(result.stderr.contains("src/i18n"))
        // Refused before reading anything, so the real site
        // catalogs were never opened.
        #expect(!result.stderr.contains("Traceback"))
    }

    // MARK: - Harness

    /// `extract-keys` is the env-var-scoped shape (see
    /// `ScriptFixture.swift`): the real script runs in place
    /// against flat temp dirs. `KIWIDESK_EXTRACT_WORKSHEETS` is
    /// set even for modes that write no worksheet — an unset
    /// override would point a regression at the developer's own
    /// checkout. `inspecting` runs against the locales directory
    /// before the fixture is torn down.
    private func runCheck(
        locales files: [String: String]
    ) throws -> ScriptRun {
        try runExtract(["--check"], locales: files)
    }

    private func runExtract(
        _ arguments: [String],
        locales files: [String: String],
        inspecting: ((URL) throws -> Void)? = nil
    ) throws -> ScriptRun {
        let base = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "kiwi-worksheet-check-\(UUID().uuidString)"
            )
        let sources = base.appendingPathComponent("Sources")
        let localesDir = base.appendingPathComponent("Locales")
        let worksheets = base.appendingPathComponent("Worksheets")
        defer { try? FileManager.default.removeItem(at: base) }
        for directory in [sources, localesDir, worksheets] {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        try #"""
        let a = L("gap.hint", "Gap between windows")
        """#
        .write(
            to: sources.appendingPathComponent("A.swift"),
            atomically: true,
            encoding: .utf8
        )
        for (name, content) in files {
            try content.write(
                to: localesDir.appendingPathComponent(name),
                atomically: true,
                encoding: .utf8
            )
        }
        let run = try runPythonScript(
            at: repoRoot.appendingPathComponent(
                "scripts/extract-keys"
            ),
            arguments: arguments,
            environment: [
                "KIWIDESK_EXTRACT_SOURCES": sources.path,
                "KIWIDESK_EXTRACT_LOCALES": localesDir.path,
                "KIWIDESK_EXTRACT_WORKSHEETS": worksheets.path,
            ]
        )
        try inspecting?(localesDir)
        return run
    }
}
