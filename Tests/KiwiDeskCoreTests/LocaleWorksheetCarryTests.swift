import Foundation
import Testing

/// Re-minting a worksheet must not destroy the translations
/// already drafted in it.
///
/// `scripts/extract-keys <locale>` rewrites
/// `missing_<locale>.json` from `en.json` against
/// `<locale>.json`. It used to compute that file without ever
/// reading the one already on disk, so every `translation` it
/// wrote was empty — and picking up newly-added English
/// mid-translation is the natural reason to re-run it. The
/// directory is gitignored and `merge-keys` is the only thing
/// that moves a translation out of it, so between minting and
/// merging the worksheet is the sole copy of the work: a re-mint
/// silently discarded days of it and reported "N missing key(s)
/// written" exactly as a first extract does.
///
/// This suite owns *what a re-mint preserves*. Where a worksheet
/// is written is `LocaleWorksheetLocationTests`, and that one
/// found among the catalogs is rejected is
/// `LocaleWorksheetRejectionTests`; all three fail apart.
@Suite("locale worksheet carry-over")
struct LocaleWorksheetCarryTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    /// One `L()` call site per key, so `extract()` mints exactly
    /// the keys a case reasons about.
    private func sources(_ pairs: [(String, String)]) -> String {
        pairs
            .map { #"let _ = L("\#($0.0)", "\#($0.1)")"# }
            .joined(separator: "\n")
    }

    private func worksheet(
        _ fx: RepoShapedFixture
    ) throws -> [String: [String: String]] {
        let object = try JSONSerialization.jsonObject(
            with: fx.rawWorksheet("missing_de.json")
        )
        return try #require(
            object as? [String: [String: String]],
            "worksheet is not a {key: {source, translation}} map"
        )
    }

    /// Writes `translation` into every entry of the worksheet on
    /// disk — the translator's half of the round trip.
    private func fill(
        _ fx: RepoShapedFixture,
        _ texts: [String: String]
    ) throws {
        var sheet = try worksheet(fx)
        for (key, text) in texts {
            sheet[key]?["translation"] = text
        }
        try JSONSerialization
            .data(withJSONObject: sheet, options: [.sortedKeys])
            .write(
                to: fx.worksheets
                    .appendingPathComponent("missing_de.json")
            )
    }

    /// The defect itself: draft, re-extract, and the draft is
    /// still there. Reverting `read_drafts` out of
    /// `write_missing` reds this on the surviving-text check.
    @Test("a re-mint carries a drafted translation over")
    func reMintCarriesDraftedTranslations() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-carry",
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([
                ("gap.hint", "Gap between windows"),
                ("bar.hint", "Bar thickness"),
            ])
        ])

        #expect(
            try runRepoScript(
                "extract-keys",
                arguments: ["de"],
                in: fx,
                repoRoot: repoRoot
            ).status == 0
        )
        try fill(fx, ["gap.hint": "Abstand zwischen Fenstern"])

        // A second key appears in the code while the worksheet is
        // out — the reason a translator re-runs the extractor at
        // all, and the run that used to cost them the draft.
        try fx.writeSources([
            "A.swift": sources([
                ("gap.hint", "Gap between windows"),
                ("bar.hint", "Bar thickness"),
                ("edge.hint", "Screen edge"),
            ])
        ])
        let rerun = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(rerun.status == 0)

        let sheet = try worksheet(fx)
        #expect(
            sheet["gap.hint"]?["translation"]
                == "Abstand zwischen Fenstern",
            "the drafted translation was destroyed by the re-mint"
        )
        // The new key arrived, and the untouched one stayed
        // blank — so the carry-over did not simply copy the old
        // file over the top of a fresh computation.
        #expect(sheet["edge.hint"]?["translation"] == "")
        #expect(sheet["bar.hint"]?["translation"] == "")
        #expect(sheet.count == 3)
    }

    /// A draft is carried only while it still translates the
    /// English on screen. `merge-keys` refuses a stale entry for
    /// the same reason; clearing it here says so a round earlier,
    /// while the new source is in front of the translator.
    @Test("a draft whose English moved is cleared, and echoed")
    func staleDraftIsClearedAndReported() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-carry-stale",
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([("gap.hint", "Gap between windows")])
        ])
        #expect(
            try runRepoScript(
                "extract-keys",
                arguments: ["de"],
                in: fx,
                repoRoot: repoRoot
            ).status == 0
        )
        try fill(fx, ["gap.hint": "Abstand zwischen Fenstern"])

        try fx.writeSources([
            "A.swift": sources([
                ("gap.hint", "Spacing around each window")
            ])
        ])
        let rerun = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(rerun.status == 0)

        let sheet = try worksheet(fx)
        #expect(
            sheet["gap.hint"]?["translation"] == "",
            "a draft of retired English was carried anyway"
        )
        #expect(
            sheet["gap.hint"]?["source"]
                == "Spacing around each window"
        )
        // Echoed with its text: the worksheet has just been
        // rewritten, so the terminal is the only copy left.
        #expect(
            rerun.stderr.contains("Abstand zwischen Fenstern"),
            "the discarded draft was dropped without a word"
        )
    }

    /// A worksheet that will not parse holds drafts that can
    /// neither be read nor knowingly discarded, so the run
    /// refuses rather than overwriting it.
    @Test("an unreadable worksheet is refused, not clobbered")
    func unreadableWorksheetIsNotOverwritten() throws {
        let damaged = #"{ "gap.hint": NOT JSON"#
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-carry-damaged",
            locales: [
                "de.json": #"{}"#,
                "missing_de.json": damaged,
            ]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([("gap.hint", "Gap between windows")])
        ])

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status != 0, "a damaged worksheet ran clean")
        let after = try String(
            data: fx.rawWorksheet("missing_de.json"),
            encoding: .utf8
        )
        #expect(after == damaged, "the damaged worksheet was lost")
    }

    /// The carry-over has to survive the trip it exists to
    /// protect: a translation drafted before a re-mint must still
    /// reach `<locale>.json`. Guards the pair rather than either
    /// script alone — a carried entry whose `source` no longer
    /// matched would be silently refused by `merge-keys`, leaving
    /// both suites above green and the translator's work stranded.
    @Test("a carried draft still merges into the catalog")
    func carriedDraftSurvivesTheRoundTrip() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-carry-merge",
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([("gap.hint", "Gap between windows")])
        ])
        #expect(
            try runRepoScript(
                "extract-keys",
                arguments: ["de"],
                in: fx,
                repoRoot: repoRoot
            ).status == 0
        )
        try fill(fx, ["gap.hint": "Abstand zwischen Fenstern"])
        #expect(
            try runRepoScript(
                "extract-keys",
                arguments: ["de"],
                in: fx,
                repoRoot: repoRoot
            ).status == 0
        )

        let merge = try runRepoScript(
            "merge-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(merge.status == 0, "\(merge.stderr)")
        #expect(
            try fx.decodeLocale("de.json")["gap.hint"]
                == "Abstand zwischen Fenstern"
        )
        #expect(!fx.worksheetExists("missing_de.json"))
    }
}
