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

    private func parse(
        _ body: String,
        tag: String? = nil,
        census: URL? = nil
    ) throws -> ScriptRun {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("spotlight-\(UUID().uuidString).md")
        try body.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: Self.script,
            arguments: ["--body", file.path]
                + (tag.map { ["--tag", $0] } ?? [])
                + (census.map { ["--census", $0.path] } ?? [])
        )
    }

    /// A landable id holding a brace pair, as census ids may
    /// (`keybinding.swap_with_{prev,next}_track`): a token that
    /// stopped at the first `}` would read a different id.
    private static let bracedID = "keybinding.swap_with_{prev,next}_track"

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
        let id = Self.bracedID
        // Its own list, so the braced id is there whatever the
        // tree's list holds.
        let census = FileManager.default.temporaryDirectory
            .appendingPathComponent("census-\(UUID().uuidString).txt")
        try "config.layers\n\(id)\n".write(
            to: census,
            atomically: true,
            encoding: .utf8
        )
        defer { try? FileManager.default.removeItem(at: census) }
        let run = try parse(rows(id), census: census)
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

    /// The list is read only when a row names a setting: a body
    /// with none never touches it, so an unreadable list cannot
    /// refuse a release that does not need it.
    @Test("the landable list is read only for a `{setting:…}`")
    func censusReadLazily() throws {
        func run(_ body: String) throws -> ScriptRun {
            let file = FileManager.default.temporaryDirectory
                .appendingPathComponent("lazy-\(UUID().uuidString).md")
            try body.write(to: file, atomically: true, encoding: .utf8)
            defer { try? FileManager.default.removeItem(at: file) }
            return try runPythonScript(
                at: Self.script,
                arguments: [
                    "--body", file.path, "--census", "/no/such/list",
                ]
            )
        }
        let plain = try run(
            rows("x").replacingOccurrences(of: " {setting:x}", with: "")
        )
        #expect(plain.status == 0, "\(plain.stderr)")
        let named = try run(rows("x"))
        #expect(named.status != 0)
        #expect(named.stderr.contains("cannot read /no/such/list"))
    }

    /// A publication check reads the TAG's own list, so a setting
    /// renamed on main after the tag cannot refuse a valid row.
    @Test("--release reads the landable list at the tag")
    func releaseReadsTheTag() throws {
        let tag = "v9999.7.0"
        let release: [String: Any] = [
            "tag_name": tag,
            "published_at": "2026-10-20T10:00:00Z",
            "draft": false,
            "html_url": "https://example.invalid/release",
            "body": rows("config.layers"),
            "assets": [],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent("tag-\(UUID().uuidString).json")
        try JSONSerialization.data(withJSONObject: [release]).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let run = try runPythonScript(
            at: Self.script,
            arguments: [
                "--release", tag, "--check", "--releases", file.path,
                "--output", "-",
            ]
        )
        #expect(run.status != 0)
        #expect(run.stderr.contains("at \(tag) — fetch the tag first"))
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
        let id = Self.bracedID
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
