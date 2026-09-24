import Foundation
import Testing

/// The typed grammar reaches `changelog.json` as data (#1542):
/// each typed section carries its machine `type` and the Before
/// you update paragraph travels as `heads`. The site, the feed
/// and the update window branch on those keys, so a generator
/// that stopped writing them would strip the counts, the Lua &
/// CLI fold and the callout with nothing else going red.
///
/// Driven through `--all --releases <fixture> --output -`, the
/// same hermetic path `ChangelogDownloadTests` takes.
@Suite("Changelog entry keys (#1542)")
struct ChangelogEntryKeysTests {
    private static let typedBody = """
        ## Highlights

        A summary sentence. And another one.

        **Before you update:** settings carry over.

        ### New

        - **A thing.**

        ### Lua & CLI

        - **A verb.**
        """

    private static let legacyBody = """
        ## Highlights

        A summary sentence.

        ### Windows behave

        - **A thing.**
        """

    private func entry(
        tag: String,
        body: String
    ) throws -> [String: Any] {
        let release: [String: Any] = [
            "tag_name": tag,
            "published_at": "2026-10-01T10:00:00Z",
            "draft": false,
            "html_url": "https://example.invalid/release",
            "body": body,
            "assets": [],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "changelog-keys-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: [release])
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let run = try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("changelog-sync"),
            arguments: [
                "--all", "--releases", file.path, "--output", "-",
            ]
        )
        #expect(run.status == 0, "\(run.stderr)")
        let object =
            try JSONSerialization
            .jsonObject(with: Data(run.stdout.utf8))
            as? [String: Any]
        let releases = object?["releases"] as? [[String: Any]]
        return try #require(releases?.first)
    }

    private func types(_ entry: [String: Any]) -> [String?] {
        let sections = entry["sections"] as? [[String: Any]] ?? []
        return sections.map { $0["type"] as? String }
    }

    @Test("a typed release carries section types and heads")
    func typedKeysWritten() throws {
        let typed = try entry(tag: "v2.0.0", body: Self.typedBody)
        #expect(types(typed) == ["new", "scripting"])
        #expect(typed["heads"] as? String == "settings carry over.")
    }

    /// The version is read off the tag's leading `vX.Y.Z`, so a
    /// prerelease is typed or not by its version, never by the
    /// suffix.
    @Test("a 2.x prerelease is typed too")
    func prereleaseTyped() throws {
        let typed = try entry(
            tag: "v2.1.0-rc.1",
            body: Self.typedBody
        )
        #expect(types(typed) == ["new", "scripting"])
    }

    @Test("a release before 2.0.0 carries neither key")
    func legacyKeysAbsent() throws {
        let legacy = try entry(
            tag: "v1.5.0-rc.1",
            body: Self.legacyBody
        )
        #expect(types(legacy) == [nil])
        #expect(legacy["heads"] == nil)
    }
}
