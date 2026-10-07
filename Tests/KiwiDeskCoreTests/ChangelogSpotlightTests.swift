import Foundation
import Testing

/// The release body's optional spotlight and the patch prose cap
/// (#2038): what `changelog-sync` accepts, the cap held at its
/// limit, and what it carries into `changelog.json`. The
/// refusals are rows of `ChangelogParserTests`
/// (`ChangelogRefusal.spotlight`).
@Suite("Changelog spotlight (#2038)")
struct ChangelogSpotlightTests {
    private static let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts")
        .appendingPathComponent("changelog-sync")

    private func parse(_ body: String, tag: String? = nil) throws
        -> ScriptRun
    {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotlight-\(UUID().uuidString).md")
        try body.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: Self.script,
            arguments: ["--body", file.path]
                + (tag.map { ["--tag", $0] } ?? [])
        )
    }

    /// A census id this tree declares, read off the script's own
    /// dump — one holding braces where there is one, since a
    /// token must not stop at the id's first `}`.
    private func censusID() throws -> String {
        let run = try runPythonScript(
            at: Self.script,
            arguments: ["--census-ids"]
        )
        #expect(run.status == 0, "\(run.stderr)")
        let ids = run.stdout.split(separator: "\n").map(String.init)
        return try #require(ids.first { $0.contains("{") } ?? ids.first)
    }

    private func rows(_ id: String) -> String {
        """
        ## Highlights

        Apps, e.g. Safari, open faster on macOS 26.1 now.

        ### Spotlight

        - **Faster Space switching** — Bars settle sooner. {symbol:bolt.fill}
        - **Find shortcuts faster** — Jump chips. \
        {setting:\(id)} {symbol:keyboard}

        ### New

        - A thing.
        """
    }

    /// One sentence despite "e.g." and "26.1", a braced census id,
    /// and the rows carried with their tokens.
    @Test("a spotlight body parses, its rows reported")
    func spotlightAccepted() throws {
        let id = try censusID()
        let run = try parse(rows(id))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(
            run.stdout.contains(
                "spotlight: Find shortcuts faster — Jump chips. "
                    + "{setting:\(id)} {symbol:keyboard}"
            )
        )
        #expect(run.stdout.contains("1 section(s)"))
    }

    private static func patch(_ summary: String) -> String {
        """
        ## Highlights

        \(summary)

        ### Fixed

        - A fix.
        """
    }

    /// Exactly two sentences and 280 characters: the limit holds,
    /// one character more refuses.
    @Test("a patch summary at the cap is accepted, past it refused")
    func patchProseCap() throws {
        let first = "A round of fixes for floating windows and the shelf."
        let second = "Each one "
        let filler = String(
            repeating: "x",
            count: 280 - first.count - 1 - second.count - 1
        )
        let atLimit = "\(first) \(second)\(filler)."
        #expect(atLimit.count == 280)
        let accepted = try parse(Self.patch(atLimit), tag: "v2.2.1")
        #expect(accepted.status == 0, "\(accepted.stderr)")

        let longer = try parse(
            Self.patch("\(first) \(second)x\(filler)."),
            tag: "v2.2.1"
        )
        #expect(longer.status != 0)
        #expect(longer.stderr.contains("a patch summary of"))

        let threeSentences = try parse(
            Self.patch("One fix. Two fixes. Three fixes."),
            tag: "v2.2.1"
        )
        #expect(threeSentences.status != 0)
        #expect(threeSentences.stderr.contains("3 sentence(s)"))
    }

    /// A minor's prose is only ever shown alone, so it stays
    /// uncapped.
    @Test("a minor's long prose is not capped")
    func minorProseUncapped() throws {
        let run = try parse(
            Self.patch("One fix. Two fixes. Three fixes. Four."),
            tag: "v2.2.0"
        )
        #expect(run.status == 0, "\(run.stderr)")
    }

    private func entry(body: String) throws -> [String: Any] {
        let release: [String: Any] = [
            "tag_name": "v2.2.0",
            "published_at": "2026-10-20T10:00:00Z",
            "draft": false,
            "html_url": "https://example.invalid/release",
            "body": body,
            "assets": [],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotlight-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: [release]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let run = try runPythonScript(
            at: Self.script,
            arguments: ["--all", "--releases", file.path, "--output", "-"]
        )
        #expect(run.status == 0, "\(run.stderr)")
        let object =
            try JSONSerialization.jsonObject(with: Data(run.stdout.utf8))
            as? [String: Any]
        let releases = object?["releases"] as? [[String: Any]]
        return try #require(releases?.first)
    }

    @Test("the rows reach changelog.json as `spotlight`")
    func spotlightWritten() throws {
        let id = try censusID()
        let written =
            try entry(body: rows(id))["spotlight"] as? [[String: String]]
        #expect(written?.count == 2)
        #expect(written?.first?["title"] == "Faster Space switching")
        #expect(written?.first?["setting"] == nil)
        #expect(written?.last?["setting"] == id)
        #expect(written?.last?["symbol"] == "keyboard")
    }

    /// History is not re-judged against a later census: a renamed
    /// id must not strip a published release of its block — the
    /// window drops the link at runtime instead.
    @Test("a history read keeps a row whose setting is gone")
    func historyIgnoresCensus() throws {
        let written =
            try entry(body: rows("retired.key"))["spotlight"]
            as? [[String: String]]
        #expect(written?.last?["setting"] == "retired.key")
    }
}
