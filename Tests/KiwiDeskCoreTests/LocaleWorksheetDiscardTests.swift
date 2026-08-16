import Foundation
import Testing

/// What a re-mint refuses to do quietly.
///
/// `LocaleWorksheetCarryTests` owns what survives a re-mint;
/// this owns what does not. Every case here is a path that
/// *removes* a translator's text — the worksheet is rewritten or
/// unlinked — and the rule is that none of them may happen in
/// silence (`.claude/rules/localization.md` ▸ "A re-mint must
/// never silently discard drafted work").
///
/// The first draft of the carry-over shipped three such paths
/// unguarded, all of them found in review: an entry whose shape
/// `read_drafts` could not use was dropped with nothing printed;
/// a worksheet saved in a non-UTF-8 encoding raised past the
/// refusal instead of hitting it; and the "no keys missing"
/// branch unlinked a worksheet holding drafts. A green suite is
/// exactly what each of them had.
@Suite("locale worksheet discards")
struct LocaleWorksheetDiscardTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func sources(_ pairs: [(String, String)]) -> String {
        pairs
            .map { #"let _ = L("\#($0.0)", "\#($0.1)")"# }
            .joined(separator: "\n")
    }

    /// The lines `_report_discarded` printed under `banner`, or
    /// `nil` when it printed no such block. Parsed rather than
    /// substring-searched so a draft echoed under a *different*
    /// banner cannot satisfy an assertion about this one — the
    /// two say different things about the translator's work.
    private func echoed(
        _ run: ScriptRun,
        under banner: String
    ) -> [String]? {
        let lines = run.stderr.components(separatedBy: "\n")
        guard
            let start = lines.firstIndex(where: {
                $0.contains(banner)
            })
        else { return nil }
        return Array(
            lines[lines.index(after: start)...]
                .prefix(while: { $0.hasPrefix("    - ") })
        )
    }

    /// The blocker the review caught: a wrong SHAPE is not the
    /// same as an empty slot. A bare-string entry IS the draft —
    /// `merge-keys` names it the likeliest hand-written form and
    /// echoes its text — so dropping it silently reintroduces
    /// the defect the carry-over exists to close.
    @Test("a malformed entry holding text is echoed, not eaten")
    func malformedEntriesAreReportedWithTheirText() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-malformed",
            locales: [
                "de.json": #"{}"#,
                "missing_de.json": #"""
                {
                  "gap.hint": "Abstand von Hand",
                  "bar.hint": {
                    "source": 123,
                    "translation": "Balkendicke"
                  }
                }
                """#,
            ]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([
                ("gap.hint", "Gap between windows"),
                ("bar.hint", "Bar thickness"),
            ])
        ])

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status == 0)
        let lines = try #require(
            echoed(run, under: "malformed"),
            "malformed drafts vanished silently: \(run.stderr)"
        )
        // Both shapes, each with the text a human typed — the
        // bare string, and the translation beside a source that
        // is not a string.
        #expect(lines.count == 2)
        #expect(
            lines.contains {
                $0.contains("gap.hint")
                    && $0.contains("Abstand von Hand")
            }
        )
        #expect(
            lines.contains {
                $0.contains("bar.hint")
                    && $0.contains("Balkendicke")
            }
        )
    }

    /// The worksheet is the one file in this pipeline a
    /// non-developer edits, so a Latin-1 save is the likeliest
    /// way it ever stops parsing. `UnicodeDecodeError` is a
    /// `ValueError`, not a `JSONDecodeError`, so the first draft
    /// raised straight past the refusal — and the refusal test
    /// that only asserted a non-zero exit counted the traceback
    /// as a pass.
    @Test("a non-UTF-8 worksheet is refused, not crashed through")
    func latin1WorksheetHitsTheRefusal() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-latin1",
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([("gap.hint", "Gap between windows")])
        ])
        let worksheet = fx.worksheets
            .appendingPathComponent("missing_de.json")
        try FileManager.default.createDirectory(
            at: fx.worksheets,
            withIntermediateDirectories: true
        )
        let damaged = try #require(
            #"{"gap.hint": {"source": "x", "translation": "Größe"}}"#
                .data(using: .isoLatin1)
        )
        try damaged.write(to: worksheet)

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status != 0)
        // The message, not just the exit code: a traceback also
        // exits non-zero, and that is precisely what shipped.
        #expect(
            run.stderr.contains("will not parse"),
            "no refusal message — did it raise instead?"
        )
        #expect(
            !run.stderr.contains("Traceback"),
            "the run crashed rather than refusing"
        )
        #expect(
            try Data(contentsOf: worksheet) == damaged,
            "the unreadable worksheet was overwritten"
        )
    }

    /// The second refusal arm, which no test reached: a
    /// worksheet that parses as JSON but is not an object.
    /// Deleting the `raise` left the whole carry suite green.
    @Test("a worksheet that is not an object is refused too")
    func nonObjectWorksheetIsRefused() throws {
        let damaged = #"["not", "a", "worksheet"]"#
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-nonobject",
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
        #expect(run.status != 0)
        #expect(run.stderr.contains("will not parse"))
        let after = try String(
            data: fx.rawWorksheet("missing_de.json"),
            encoding: .utf8
        )
        #expect(after == damaged, "a non-object worksheet was lost")
    }

    /// Two causes, two banners. Telling a translator their key is
    /// "already translated" when it was deleted from the app
    /// sends them looking in `<locale>.json` for something that
    /// is gone — `merge-keys` splits its own drop classes for the
    /// same reason.
    @Test("an undroppable draft names which of the two it is")
    func orphanedDraftsAreReportedApart() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-orphans",
            locales: [
                "de.json": #"{"gap.hint": "Schon übersetzt"}"#,
                "missing_de.json": #"""
                {
                  "gap.hint": {
                    "source": "Gap between windows",
                    "translation": "Abstand"
                  },
                  "ghost.key": {
                    "source": "Gone from the app",
                    "translation": "Weg"
                  }
                }
                """#,
            ]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([
                ("gap.hint", "Gap between windows"),
                ("bar.hint", "Bar thickness"),
            ])
        ])

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(run.status == 0)
        let translated = try #require(
            echoed(run, under: "already translates"),
            "the merged draft was not reported: \(run.stderr)"
        )
        #expect(translated.count == 1)
        #expect(translated[0].contains("gap.hint"))
        #expect(translated[0].contains("Abstand"))

        let departed = try #require(
            echoed(run, under: "left en.json"),
            "the deleted key's draft was not reported"
        )
        #expect(departed.count == 1)
        #expect(departed[0].contains("ghost.key"))
        #expect(departed[0].contains("Weg"))
    }

    /// The one path that still *deletes* a worksheet: every key
    /// is translated, so there is nothing to mint and the file
    /// goes. Whatever it was holding is echoed first — this
    /// branch was the last silent discard, and it is the one a
    /// re-mint reaches on the run right after a merge.
    @Test("the no-keys-missing unlink echoes what it deletes")
    func unlinkBranchEchoesBeforeDeleting() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-unlink",
            locales: [
                "de.json": #"{"gap.hint": "Abstand"}"#,
                "missing_de.json": #"""
                {
                  "gap.hint": {
                    "source": "Gap between windows",
                    "translation": "Handarbeit"
                  }
                }
                """#,
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
        #expect(run.status == 0)
        let lines = try #require(
            echoed(run, under: "already translates"),
            """
            the worksheet was deleted without echoing what was \
            in it: \(run.stderr)
            """
        )
        #expect(lines.contains { $0.contains("Handarbeit") })
        #expect(!fx.worksheetExists("missing_de.json"))
        // And no empty tree left behind reading as "a pass is
        // open" — `merge-keys` prunes after its own unlink.
        #expect(
            !FileManager.default.fileExists(
                atPath: fx.worksheets.path
            )
        )
    }
}
