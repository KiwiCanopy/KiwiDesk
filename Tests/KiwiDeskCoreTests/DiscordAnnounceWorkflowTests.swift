import Foundation
import Testing

/// Where the Discord release post runs (#1627, #2521): after the
/// release sync PR has merged and the site it deploys serves the
/// release, never from the sync job that opens that PR — a post
/// from there went out on v3.2.0 while the PR was still open, so
/// the feed and the release-notes page did not know the release.
///
/// Reads through `workflowSource` / `workflowStep`, and RUNS the
/// step that decides which merge posts, over commit messages
/// shaped like the squash merge the sync PR becomes.
///
/// **What this cannot see:** whether GitHub runs a push workflow
/// for a merge at all — a sync PR merged by `github.token` fires
/// none, which the workflow's dispatch covers — and whether the
/// squash merge keeps the PR body as its commit body, a repository
/// setting (`PR_BODY`) no file holds.
@Suite("Discord release announcement workflow (#2521)")
struct DiscordAnnounceWorkflowTests {
    static let workflow = "release-announce.yml"
    static let findStep = "Find the release this merge announces"
    static let waitStep = "Wait for the deployed feed to list it"
    static let postStep = "Post the curated notes"
    static let prStep = "Open a PR if anything moved, and let it land"
    /// The line both sides spell: the sync writes it, the post
    /// asks for it.
    static let askLine = "Announce-Release: $TAG"
    static let title =
        "chore(site): sync release notes and feed for ${LABEL}"

    @Test("the sync workflow posts nothing")
    func syncNeverPosts() throws {
        let sync = try workflowSource("changelog.yml")
        #expect(!sync.contains("discord-announce"))
        #expect(!sync.contains("DISCORD_RELEASE_WEBHOOK"))
    }

    @Test("the post runs on main's push, never on publication")
    func postRunsOnTheMergedPush() throws {
        let yaml = try workflowSource(Self.workflow)
        let trigger = try #require(
            yaml.components(separatedBy: "\njobs:").first?
                .components(separatedBy: "\non:\n").last
        )
        #expect(trigger.contains("push:\n    branches: [main]"))
        for event in ["release:", "pull_request", "workflow_run"] {
            #expect(!trigger.contains(event), "triggered by \(event)")
        }
    }

    @Test("the post waits for the deployed feed and never blocks")
    func postWaitsForTheFeed() throws {
        let yaml = try workflowSource(Self.workflow)
        let find = try workflowStep(Self.findStep, in: yaml)
        let wait = try workflowStep(Self.waitStep, in: yaml)
        let post = try workflowStep(Self.postStep, in: yaml)
        let order = try [find, wait, post].map {
            try #require(yaml.range(of: $0)).lowerBound
        }
        #expect(order[0] < order[1] && order[1] < order[2])
        #expect(post.contains("scripts/discord-announce"))
        #expect(post.contains("continue-on-error: true"))
        #expect(
            post.contains(
                "DISCORD_RELEASE_WEBHOOK: "
                    + "${{ secrets.DISCORD_RELEASE_WEBHOOK }}"
            )
        )
        // A failed wait must skip the post: no status function
        // in the gate, and no continue-on-error on the wait.
        #expect(!wait.contains("continue-on-error"))
        for status in ["always()", "failure()", "cancelled()"] {
            #expect(!post.contains(status), "the post spells \(status)")
        }
        // The feed every installed copy reads, not another URL.
        let feed = try #require(try buildAppPlistValue("SUFeedURL"))
        #expect(wait.contains("FEED: \(feed)"))
        #expect(wait.contains("<sparkle:shortVersionString>${TAG#v}<"))
    }

    @Test("the sync asks for the post on publication alone")
    func syncWritesTheAsk() throws {
        let sync = try workflowSource("changelog.yml")
        let step = try workflowStep(Self.prStep, in: sync)
        #expect(step.contains(Self.title))
        #expect(step.contains(Self.askLine))
        #expect(
            step.contains(
                "${{ github.event_name == 'release' || inputs.announce }}"
            )
        )
        #expect(
            step.contains(
                #"if [ "$ANNOUNCE" = "true" ] && [ -n "$TAG" ]; then"#
            )
        )
    }

    @Test("only a sync merge that asks for it posts")
    func onlyAnAskedSyncMergePosts() throws {
        let subject =
            Self.title.replacingOccurrences(
                of: "${LABEL}",
                with: "v9.1.0"
            ) + " (#2520)"
        let ask = Self.askLine.replacingOccurrences(
            of: "$TAG",
            with: "v9.1.0"
        )
        let trailer = "\n\nCo-authored-by: bot <bot@example.invalid>"
        #expect(
            try decide("\(subject)\n\nnotes\n\n\(ask)\(trailer)")
                == "v9.1.0"
        )
        // GitHub may hand the body back with CRLF line ends.
        #expect(
            try decide("\(subject)\r\n\r\nnotes\r\n\r\n\(ask)\r\n")
                == "v9.1.0"
        )
        // A rebuild: the same merge with no ask.
        #expect(try decide("\(subject)\n\nnotes\(trailer)") == "")
        // Another release's ask, and a non-sync commit.
        #expect(
            try decide(
                "\(subject)\n\nAnnounce-Release: v9.0.0\(trailer)"
            ) == ""
        )
        #expect(try decide("feat: something\n\n\(ask)") == "")
    }

    /// The tag the find step writes for a push of `message`, or
    /// "" when it writes none.
    private func decide(_ message: String) throws -> String {
        let step = try workflowStep(
            Self.findStep,
            in: workflowSource(Self.workflow)
        )
        let lines = step.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0.hasSuffix("run: |") }
        )
        let body = lines[(start + 1)...]
        let indent =
            body.first { !$0.isEmpty }?
            .prefix { $0 == " " }.count ?? 0
        let script = body.map { String($0.dropFirst(indent)) }
            .joined(separator: "\n")
        let output = FileManager.default.temporaryDirectory
            .appendingPathComponent("announce-\(UUID().uuidString)")
        try Data().write(to: output)
        defer { try? FileManager.default.removeItem(at: output) }
        let run = try spawn(
            "/bin/bash",
            ["-e", "-c", script],
            environment: [
                "EVENT": "push",
                "MESSAGE": message,
                "GITHUB_OUTPUT": output.path,
                "PATH": "/usr/bin:/bin",
            ]
        )
        #expect(run.status == 0, "\(run.stderr)")
        let written = try String(contentsOf: output, encoding: .utf8)
        return
            written
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "tag=", with: "")
    }
}
