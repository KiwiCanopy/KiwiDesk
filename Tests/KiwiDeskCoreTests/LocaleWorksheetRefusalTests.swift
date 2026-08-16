import Foundation
import Testing

/// A worksheet `extract-keys` cannot read is left alone.
///
/// Three ways one stops being readable, one `except` arm each in
/// `read_drafts`, and all three end the same way: refuse, say
/// so, and do not write. The drafts in such a file can neither
/// be carried nor knowingly discarded, so overwriting it is the
/// one move the tool must never make — the reasoning is in
/// `.claude/rules/localization.md` ▸ "A re-mint must never
/// silently discard drafted work".
///
/// Split from `LocaleWorksheetDiscardTests` on the 350-line
/// ceiling. That suite owns what a re-mint *reports and drops*;
/// this owns what it *declines to touch*. They fail apart —
/// nothing here reads a discard banner, and nothing there feeds
/// an unreadable file.
///
/// Each arm has been watched by nothing at some point in this
/// change's history, which is why they are enumerated rather
/// than represented by one case: the UTF-8 arm shipped as a
/// traceback behind a test that only checked the exit code, the
/// non-object arm could be deleted with the whole suite green,
/// and the plain-invalid-JSON arm was briefly orphaned when the
/// original refusal test moved files.
@Suite("locale worksheet refusals")
struct LocaleWorksheetRefusalTests {
    private var repoRoot: URL { scriptFixtureRepoRoot() }

    private func sources(_ pairs: [(String, String)]) -> String {
        pairs
            .map { #"let _ = L("\#($0.0)", "\#($0.1)")"# }
            .joined(separator: "\n")
    }

    /// Runs `extract-keys de` over a fixture whose worksheet is
    /// `body`, and asserts the refusal: non-zero, the message
    /// rather than a traceback, and the file byte-identical.
    ///
    /// The traceback check is the load-bearing one. A crash also
    /// exits non-zero, so a refusal test that stops at the exit
    /// code passes on exactly the bug this suite exists to catch
    /// — which is what shipped.
    private func expectRefusal(
        of body: Data,
        prefix: String,
        sourceLine: SourceLocation = #_sourceLocation
    ) throws {
        let fx = try makeRepoShapedFixture(
            prefix: prefix,
            locales: ["de.json": #"{}"#]
        )
        defer { fx.cleanup() }
        try fx.writeSources([
            "A.swift": sources([("gap.hint", "Gap between windows")])
        ])
        try FileManager.default.createDirectory(
            at: fx.worksheets,
            withIntermediateDirectories: true
        )
        let worksheet = fx.worksheets
            .appendingPathComponent("missing_de.json")
        try body.write(to: worksheet)

        let run = try runRepoScript(
            "extract-keys",
            arguments: ["de"],
            in: fx,
            repoRoot: repoRoot
        )
        #expect(
            run.status != 0,
            "an unreadable worksheet ran clean",
            sourceLocation: sourceLine
        )
        #expect(
            run.stderr.contains("will not parse"),
            "no refusal message — did it raise instead?",
            sourceLocation: sourceLine
        )
        #expect(
            !run.stderr.contains("Traceback"),
            "the run crashed rather than refusing",
            sourceLocation: sourceLine
        )
        #expect(
            try Data(contentsOf: worksheet) == body,
            "the unreadable worksheet was overwritten",
            sourceLocation: sourceLine
        )
    }

    /// The plainest arm — a stray comma, a truncated save —
    /// and the one `json.JSONDecodeError` exists for.
    @Test("a syntactically invalid worksheet is refused")
    func malformedJSONWorksheetIsRefused() throws {
        try expectRefusal(
            of: try #require(
                #"{ "gap.hint": NOT JSON"#.data(using: .utf8)
            ),
            prefix: "kiwi-worksheet-badjson"
        )
    }

    /// The worksheet is the one file in this pipeline a
    /// non-developer edits, so a Latin-1 save is the likeliest
    /// way it ever stops parsing. `UnicodeDecodeError` is a
    /// `ValueError`, not a `JSONDecodeError`, so the first draft
    /// raised straight past the refusal.
    @Test("a non-UTF-8 worksheet is refused, not crashed through")
    func latin1WorksheetHitsTheRefusal() throws {
        try expectRefusal(
            of: try #require(
                #"{"gap.hint": {"source": "x", "translation": "Größe"}}"#
                    .data(using: .isoLatin1)
            ),
            prefix: "kiwi-worksheet-latin1"
        )
    }

    /// Valid JSON, wrong shape. Deleting this `raise` left every
    /// other worksheet test green.
    @Test("a worksheet that is not an object is refused too")
    func nonObjectWorksheetIsRefused() throws {
        try expectRefusal(
            of: try #require(
                #"["not", "a", "worksheet"]"#.data(using: .utf8)
            ),
            prefix: "kiwi-worksheet-nonobject"
        )
    }
}
