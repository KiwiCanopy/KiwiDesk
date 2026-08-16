import Foundation
import Testing

/// Re-minting a worksheet must not destroy the translations
/// already drafted in it.
///
/// `scripts/extract-keys <locale>` rewrites
/// `missing_<locale>.json` from `en.json` against
/// `<locale>.json`, and used to compute that file without ever
/// reading the one already on disk — so every `translation` it
/// wrote came out empty. Why that costs a translator everything
/// drafted since their last merge is argued once, in
/// `.claude/rules/localization.md` ▸ "A re-mint must never
/// silently discard drafted work".
///
/// This suite owns *what a re-mint preserves* — the carry, the
/// clear, and the round trip that proves a carried draft is
/// still one `merge-keys` will take. What a re-mint *discards*,
/// and the refusals, are `LocaleWorksheetDiscardTests`: the two
/// split on the 350-line ceiling, and they fail apart, since
/// nothing here reads a discard banner other than the stale one.
/// Where a worksheet is written is `LocaleWorksheetLocationTests`,
/// and that one found among the catalogs is rejected is
/// `LocaleWorksheetRejectionTests`.
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
        // Echoed with its text, under the banner that names WHY.
        // A bare substring search over stderr passes when the
        // same draft is echoed under the "no longer missing"
        // banner instead — a different claim about the
        // translator's work, so pin the reason and the key.
        let echo = try #require(
            rerun.stderr
                .components(separatedBy: "\n")
                .drop(while: { !$0.contains("English has changed") })
                .dropFirst().first,
            """
            no draft was echoed under the changed-English \
            banner: \(rerun.stderr)
            """
        )
        #expect(echo.contains("gap.hint"))
        #expect(echo.contains("Abstand zwischen Fenstern"))
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
