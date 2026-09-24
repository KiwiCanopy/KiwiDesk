import Foundation
import Testing

/// `scripts/discord-announce` posts a published release's curated
/// block to Discord (#1627): the summary, Before you update, and
/// each section with its count — never the generated list — cut
/// at a section boundary to fit an embed, and never failing the
/// release sync when the webhook is absent.
///
/// Driven through `--dry-run` over a releases fixture, so no test
/// touches the network or the webhook.
@Suite("Discord release announcement (#1627)")
struct DiscordAnnounceTests {
    private static let tag = "v9999.3.0"
    private static let url = "https://example.invalid/release"

    private func script() -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("discord-announce")
    }

    private func run(
        body: String,
        arguments: [String] = ["--dry-run"],
        environment: [String: String]? = nil
    ) throws -> ScriptRun {
        let release: [String: Any] = [
            "tag_name": Self.tag,
            "published_at": "2026-10-01T10:00:00Z",
            "draft": false,
            "html_url": Self.url,
            "body": body,
            "assets": [],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "discord-releases-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: [release])
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: script(),
            arguments: ["--release", Self.tag, "--releases", file.path]
                + arguments,
            environment: environment
        )
    }

    private func embed(_ run: ScriptRun) throws -> [String: Any] {
        let object =
            try JSONSerialization
            .jsonObject(with: Data(run.stdout.utf8)) as? [String: Any]
        let embeds = object?["embeds"] as? [[String: Any]]
        return try #require(embeds?.first)
    }

    private static let body = """
        ## Highlights

        Both bars on one shelf. Profiles fit every screen setup.

        **Before you update:** your settings carry over.

        ### New

        - **One shelf** for both bars.
        - **Per setup** bindings.

        ### Fixed

        - **⌘W closes Settings.**

        ## What's Changed
        * fix(bars): something reviewers say by @someone
        """

    @Test("the post is the curated block, with counts")
    func postIsTheCuratedBlock() throws {
        let result = try run(body: Self.body)
        #expect(result.status == 0, "\(result.stderr)")
        let embed = try embed(result)
        let text = try #require(embed["description"] as? String)
        #expect(embed["title"] as? String == "KiwiDesk 9999.3.0")
        #expect(embed["url"] as? String == Self.url)
        #expect(text.hasPrefix("Both bars on one shelf."))
        #expect(text.contains("**Before you update:** your settings"))
        #expect(text.contains("**New · 2**\n- **One shelf** for both bars."))
        #expect(text.contains("**Fixed · 1**"))
        #expect(!text.contains("fix(bars)"))
    }

    /// A release post must never ping the channel, whatever the
    /// notes happen to contain.
    @Test("the post mentions nobody")
    func noMentions() throws {
        let result = try run(body: Self.body)
        let object =
            try JSONSerialization
            .jsonObject(with: Data(result.stdout.utf8)) as? [String: Any]
        let mentions = object?["allowed_mentions"] as? [String: Any]
        #expect(mentions?["parse"] as? [String] == [])
    }

    /// Past the embed limit the post ends on a whole section and a
    /// pointer to the full notes, never a cut sentence.
    @Test("a long body is cut at a section boundary")
    func longBodyCutAtSection() throws {
        let bullet = "- **A change** " + String(repeating: "word ", count: 60)
        let section = (1...12).map { _ in bullet }.joined(separator: "\n")
        let body = """
            ## Highlights

            A summary. And another sentence.

            ### New

            \(section)

            ### Improved

            \(section)

            ### Fixed

            \(section)
            """
        let result = try run(body: body)
        #expect(result.status == 0, "\(result.stderr)")
        let text = try #require(try embed(result)["description"] as? String)
        #expect(text.count <= 4096)
        #expect(text.hasSuffix("Full notes: \(Self.url)"))
        #expect(text.contains("**New · 12**"))
        #expect(!text.contains("**Fixed · 12**"))
        // Whole sections only: every bullet shown is complete.
        let shown = text.components(separatedBy: "- **A change**").count - 1
        #expect(shown % 12 == 0)
    }

    /// A fork's run or a rotated webhook must not fail the sync.
    @Test("no webhook skips with a notice and succeeds")
    func missingWebhookSkips() throws {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let result = try run(
            body: Self.body,
            arguments: [],
            environment: ["PATH": path]
        )
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout.contains("was not announced"))
    }

    @Test("a body the parser refuses is not announced")
    func refusedBodyNotPosted() throws {
        let result = try run(body: "No curated block at all.")
        #expect(result.status != 0)
        #expect(result.stderr.contains("no `## Highlights` block"))
    }

    /// Publication only, and never able to fail the sync: a
    /// dispatch rebuild would announce an old release again.
    @Test("the workflow posts on publication and never blocks")
    func workflowGuardsThePost() throws {
        let yaml = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent(".github/workflows/changelog.yml"),
            encoding: .utf8
        )
        let step = try #require(
            ReleaseSyncTokenTests.steps(in: yaml).first {
                $0.contains("scripts/discord-announce")
            }
        )
        #expect(step.contains("if: github.event_name == 'release'"))
        #expect(step.contains("continue-on-error: true"))
        #expect(
            step.contains(
                "DISCORD_RELEASE_WEBHOOK: "
                    + "${{ secrets.DISCORD_RELEASE_WEBHOOK }}"
            )
        )
    }
}
