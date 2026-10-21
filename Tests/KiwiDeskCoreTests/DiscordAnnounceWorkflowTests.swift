import Foundation
import Testing

/// Where the Discord release post runs (#1627, #2521): after the
/// release sync PR has merged and the site it deploys serves the
/// release, never from the sync job that opens that PR — a post
/// from there went out on v3.2.0 while the PR was still open, so
/// the feed and the release-notes page did not know the release.
///
/// Reads through `workflowSource` / `workflowStep`, and RUNS both
/// halves of the handshake: the sync step that builds the PR body,
/// and the step that reads the merge's commit message for the ask.
///
/// **What this cannot see:** whether GitHub runs a push workflow
/// for a merge at all — a sync PR merged by `github.token` fires
/// none, which the sync job's notice and the dispatch cover — and
/// whether GitHub's auto-merge commits the body the arming passed.
/// Only a real release answers those.
@Suite("Discord release announcement workflow (#2521)")
struct DiscordAnnounceWorkflowTests {
    static let workflow = "release-announce.yml"
    static let findStep = "Find the release this merge announces"
    static let waitStep = "Wait for the deployed feed to list it"
    static let postStep = "Post the curated notes"
    static let prStep = "Open a PR if anything moved, and let it land"

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
        let step = try workflowStep(
            Self.prStep,
            in: workflowSource("changelog.yml")
        )
        #expect(
            step.contains(
                "${{ github.event_name == 'release' || inputs.announce }}"
            )
        )
        // The commit body is passed at the arming, never left to a
        // repository default that could drop the ask.
        #expect(
            step.contains(
                #"gh pr merge "$BRANCH" --auto --squash --body "$BODY""#
            )
        )
    }

    @Test("only a sync merge that asks for it posts")
    func onlyAnAskedSyncMergePosts() throws {
        let subject =
            "chore(site): sync release notes and feed for v9.1.0 (#2520)"
        let trailer = "\n\nCo-authored-by: bot <bot@example.invalid>"
        func merged(_ announce: String, _ tag: String) throws -> String {
            let body = try syncBody(announce: announce, tag: tag)
            return "\(subject)\n\n\(body)\(trailer)"
        }
        // Publication, or a dispatch that sets `announce`.
        #expect(try decide(merged("true", "v9.1.0")) == "v9.1.0")
        // GitHub may hand the body back with CRLF line ends.
        let crlf = try merged("true", "v9.1.0")
            .replacingOccurrences(of: "\n", with: "\r\n")
        #expect(try decide(crlf) == "v9.1.0")
        // A rebuild, of one tag or of every release.
        #expect(try decide(merged("false", "v9.1.0")) == "")
        #expect(try decide(merged("true", "")) == "")
        // A line merely quoting the ask, in a note or a reply.
        let quoted =
            try merged("false", "v9.1.0")
            + "\n> Announce-Release: v9.1.0"
        #expect(try decide(quoted) == "")
    }

    /// The body the sync step builds for a new PR, run from the
    /// step itself: from its first `ASK=` to the PR lookup.
    private func syncBody(announce: String, tag: String) throws -> String {
        let step = try workflowStep(
            Self.prStep,
            in: workflowSource("changelog.yml")
        )
        let lines = step.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0.contains(#"ASK="""#) }
        )
        let end = try #require(
            lines.firstIndex { $0.contains(#"STATE="$(gh pr view"#) }
        )
        let script =
            try dedented(lines[start..<end])
            + "\nprintf '%s' \"$BODY\""
        let run = try spawn(
            "/bin/bash",
            ["-e", "-u", "-c", script],
            environment: [
                "MESSAGE": "chore(site): sync\n\nGenerated.",
                "RETIRED": "",
                "TAG": tag,
                "ANNOUNCE": announce,
                "PATH": "/usr/bin:/bin",
            ]
        )
        try #require(run.status == 0, "\(run.stderr)")
        return run.stdout
    }

    /// Lines of a `run: |` block as the shell receives them.
    private func dedented(_ lines: ArraySlice<Substring>) throws -> String {
        let indent =
            try #require(lines.first { !$0.isEmpty })
            .prefix { $0 == " " }.count
        return lines.map { String($0.dropFirst(indent)) }
            .joined(separator: "\n")
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
        let script = try dedented(lines[(start + 1)...])
        let output =
            testTemporaryDirectory
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
