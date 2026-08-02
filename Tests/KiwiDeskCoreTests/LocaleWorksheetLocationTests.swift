import Foundation
import Testing

/// A translator worksheet is not a catalog, and must never share
/// a directory with one.
///
/// `Sources/KiwiDeskCore/Resources/Locales` is read by everything
/// that treats a `*.json` there as a flat `{key: value}` catalog:
/// `LocaleCatalog` at runtime (a worksheet becomes a selectable
/// language named `missing_de` whose every key falls back to
/// English), the `CFBundleLocalizations` glob in
/// `scripts/build-app.sh`, and the Swift guards that decode the
/// whole directory. SwiftPM `.copy`s the directory wholesale, so
/// a committed worksheet ships inside the `.app`.
///
/// `scripts/extract-keys` used to write the worksheet straight
/// into that directory, which made every one of those readers
/// wrong for as long as a translation pass was open — observed as
/// `SettingKeyLocaleTests` failing with a `typeMismatch` naming
/// whichever key sorted first, with nothing pointing at the
/// worksheet.
///
/// Two halves, and they fail apart: the first pins where
/// `extract-keys` writes (revert the write path and it reds); the
/// second pins that a worksheet found in the catalog directory is
/// still *rejected* rather than skipped, so the fix cannot decay
/// into teaching each reader to ignore what it cannot decode.
@Suite("locale worksheet location")
struct LocaleWorksheetLocationTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    @Test("extract-keys writes the worksheet outside Locales")
    func worksheetIsWrittenOutsideTheCatalogDirectory() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-location",
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": #"""
            let a = L("gap.hint", "Gap between windows")
            """#
        ])

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status == 0)

        // Present where it belongs — asserted before the absence
        // below, so a run that wrote no worksheet at all cannot
        // pass this as a clean directory. Both are non-throwing
        // existence checks so that a violation prints the message
        // that names it; the content check follows.
        #expect(
            fx.worksheetExists("missing_de.json"),
            "extract-keys wrote no worksheet to locale-worksheets/"
        )
        #expect(
            !fx.localeFileExists("missing_de.json"),
            """
            extract-keys wrote a worksheet into the shipped \
            catalog directory
            """
        )
        let worksheet =
            try JSONSerialization.jsonObject(
                with: fx.rawWorksheet("missing_de.json")
            ) as? [String: [String: String]]
        // Equality, not `!= nil`: an empty `source` is non-nil,
        // so the weaker form left this green under a mutation
        // that dropped the English on its way into the worksheet
        // while the `--site` sibling reded.
        #expect(
            worksheet?["gap.hint"]?["source"]
                == "Gap between windows"
        )
    }

    /// `--site` moved with it. The site's manifests are imported
    /// statically by the Astro components rather than enumerated,
    /// so a worksheet there is the milder half of the same
    /// mistake — but one rule, one place, and nothing else pins
    /// where a site worksheet lands.
    @Test("--site writes the worksheet outside src/i18n")
    func siteWorksheetIsWrittenOutsideItsCatalogs() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-location-site",
            locales: [:],
            siteLocales: [
                "en.json": #"{"hero.title": "Tiling, quietly"}"#,
                "de.json": #"{}"#,
            ]
        )
        defer { fx.cleanup() }

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["--site", "de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status == 0)
        #expect(
            fx.worksheetExists("missing_de.json", site: true),
            "no site worksheet was written"
        )
        #expect(
            !fx.localeFileExists("missing_de.json", site: true),
            """
            extract-keys --site wrote a worksheet into \
            site/src/i18n
            """
        )
        // Existence alone pins the key only while this fixture is
        // one key wide (a run that computes nothing missing
        // writes no file at all). Assert the content so a second
        // fixture key cannot quietly cost the suite that.
        let worksheet =
            try JSONSerialization.jsonObject(
                with: fx.rawWorksheet(
                    "missing_de.json",
                    site: true
                )
            ) as? [String: [String: String]]
        #expect(
            worksheet?["hero.title"]?["source"]
                == "Tiling, quietly"
        )
    }

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
