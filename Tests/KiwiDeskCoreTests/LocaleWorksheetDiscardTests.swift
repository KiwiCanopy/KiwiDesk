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
/// The first draft of the carry-over shipped several such paths
/// unguarded, every one found in review: an entry whose shape
/// `read_drafts` could not use was dropped with nothing printed,
/// a draft under a mistyped field name likewise, and the "no
/// keys missing" branch unlinked a worksheet holding drafts. A
/// green suite is exactly what each of them had.
///
/// A worksheet that cannot be READ at all is the neighbouring
/// case, and `LocaleWorksheetRefusalTests` owns it — split off
/// on the 350-line ceiling. The two fail apart: nothing there
/// reads a discard banner, and nothing here feeds an unreadable
/// file.
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
                // One entry per arm `read_drafts` can classify
                // as unusable. Silencing an arm no fixture
                // reaches costs nothing, so all four are here:
                // a bare string, a non-string `source` beside
                // real text, a non-string `translation`, and a
                // value that is neither object nor string.
                "missing_de.json": #"""
                {
                  "gap.hint": "Abstand von Hand",
                  "bar.hint": {
                    "source": 123,
                    "translation": "Balkendicke"
                  },
                  "edge.hint": {
                    "source": "Screen edge",
                    "translation": 42
                  },
                  "pile.hint": ["Stapel", "Fenster"]
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
        // One line per arm, each carrying what was typed. The
        // count is what catches a partial silencing: three
        // `contains` checks all pass while a fourth arm has gone
        // quiet, and an unreached arm is one a later edit can
        // delete for free.
        #expect(lines.count == 4)
        for (key, text) in [
            ("gap.hint", "Abstand von Hand"),
            ("bar.hint", "Balkendicke"),
            ("edge.hint", "42"),
            ("pile.hint", "Stapel"),
        ] {
            #expect(
                lines.contains {
                    $0.contains(key) && $0.contains(text)
                },
                "\(key) was not echoed with its text"
            )
        }
    }

    /// An entry that keeps its draft under a mistyped field name
    /// has no `translation` at all, so both text-bearing arms
    /// miss it — the last input whose prose the rewrite could
    /// eat in silence.
    @Test("a draft under a mistyped field name is still echoed")
    func mistypedFieldNameIsReported() throws {
        let fx = try makeRepoShapedFixture(
            prefix: "kiwi-worksheet-typo",
            locales: [
                "de.json": #"{}"#,
                "missing_de.json": #"""
                {
                  "gap.hint": {
                    "source": "Gap between windows",
                    "translaton": "Vertippter Feldname"
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
            echoed(run, under: "malformed"),
            "a mistyped field name ate the draft: \(run.stderr)"
        )
        #expect(
            lines.contains { $0.contains("Vertippter Feldname") }
        )
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
        // And the summary line says so too. The echo is on
        // stderr; this is the line a human skims and a wrapper
        // captures, and "nothing written" alone reads as a
        // clean success on the one path that deletes a file.
        #expect(
            run.stdout.contains("deleted a worksheet"),
            """
            the summary line read as a clean success while \
            deleting drafted work: \(run.stdout)
            """
        )
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
