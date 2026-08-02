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
/// This suite owns the *write* half — where `extract-keys` puts
/// a worksheet, and that the directory it puts one in is
/// gitignored under that same name. The other half, that one
/// found among the catalogs is still *rejected* rather than
/// skipped, is `LocaleWorksheetRejectionTests`. They fail apart:
/// reverting the write path leaves the rejection green, and
/// deleting the rejection leaves the write path green.
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

    /// `.gitignore` is the one mirror of the directory name that
    /// nothing else pins. The Swift fixture copy is forget-proof
    /// by construction — the tests above run the real script and
    /// assert on the fixture path, so a rename in
    /// `scripts/locale_paths.py` reds them — but a rename leaves
    /// the ignore entry stale in silence, and the symptom is a
    /// translator's in-progress worksheets becoming visible and
    /// committable again (parity-tests.md: a shipped mirror
    /// carries a parity test).
    ///
    /// It substring-matches the entry rather than asking git, so
    /// a later negation (`!/locale-worksheets/`) would still
    /// satisfy it. That is the shape this file has never had, and
    /// spawning git to answer it would buy a process per run.
    @Test("the worksheet directory is gitignored under its name")
    func worksheetDirectoryIsIgnoredUnderItsRealName() throws {
        let root = scriptFixtureRepoRoot()
        let name = try String(
            contentsOf:
                root
                .appendingPathComponent("scripts")
                .appendingPathComponent("locale_paths.py"),
            encoding: .utf8
        )
        .components(separatedBy: "WORKSHEETS_DIRNAME = \"")
        .dropFirst().first?
        .components(separatedBy: "\"").first
        let dirname = try #require(name, "the constant is gone")
        #expect(!dirname.isEmpty)
        let ignores = try String(
            contentsOf: root.appendingPathComponent(".gitignore"),
            encoding: .utf8
        )
        #expect(
            ignores.contains("/\(dirname)/"),
            """
            \(dirname) is not gitignored — worksheets in \
            progress would be committable
            """
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
}
