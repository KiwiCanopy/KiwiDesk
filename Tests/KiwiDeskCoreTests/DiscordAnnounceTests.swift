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
        environment: [String: String]? = nil,
        assets: [[String: Any]] = []
    ) throws -> ScriptRun {
        let release: [String: Any] = [
            "tag_name": Self.tag,
            "published_at": "2026-10-01T10:00:00Z",
            "draft": false,
            "html_url": Self.url,
            "body": body,
            "assets": assets,
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

    /// The head alone can pass the embed limit; it is clipped at
    /// a sentence so the pointer to the full notes still fits.
    @Test("a summary past the limit is clipped, not rejected")
    func longSummaryClipped() throws {
        let sentence = String(repeating: "word ", count: 30) + "end. "
        let body = """
            ## Highlights

            \(String(repeating: sentence, count: 40))

            ### New

            - **A change.**
            """
        let result = try run(body: body)
        #expect(result.status == 0, "\(result.stderr)")
        let text = try #require(try embed(result)["description"] as? String)
        #expect(text.count <= 4096)
        #expect(text.hasSuffix("Full notes: \(Self.url)"))
    }

    /// The issue's "a link to the release and the download": the
    /// release's own image, as the site promotes it.
    @Test("the post links the download when there is one")
    func downloadLinked() throws {
        let image = "https://example.invalid/KiwiDesk-9999.3.0.dmg"
        let result = try run(
            body: Self.body,
            assets: [
                [
                    "name": "KiwiDesk-9999.3.0.dmg",
                    "browser_download_url": image,
                ]
            ]
        )
        let text = try #require(try embed(result)["description"] as? String)
        #expect(text.contains("Download: \(image)"))
    }

    /// The webhook URL is the secret: a malformed one fails the
    /// post without being printed.
    @Test("a malformed webhook fails without printing it")
    func malformedWebhookNotPrinted() throws {
        let path = ProcessInfo.processInfo.environment["PATH"] ?? ""
        let result = try run(
            body: Self.body,
            arguments: [],
            environment: [
                "PATH": path,
                "DISCORD_RELEASE_WEBHOOK": "not-a-url secretvalue",
            ]
        )
        #expect(result.status != 0)
        #expect(!result.stderr.contains("secretvalue"))
        #expect(!result.stdout.contains("secretvalue"))
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
        #expect(step.contains("continue-on-error: true"))
        #expect(
            step.contains(
                "DISCORD_RELEASE_WEBHOOK: "
                    + "${{ secrets.DISCORD_RELEASE_WEBHOOK }}"
            )
        )
        // Its own job, after the sync: a re-run of a failed sync
        // must not post again, and nothing posts before the sync
        // proved the notes.
        let job = try #require(
            yaml.components(separatedBy: "\n  announce:\n").last
        )
        #expect(yaml.contains("\n  announce:\n"))
        #expect(job.contains("needs: sync"))
        #expect(job.contains("github.event_name == 'release'"))
        #expect(job.contains("inputs.announce && inputs.tag != ''"))
    }
}
