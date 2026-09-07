import Foundation
import Testing

/// The token half of `ReleaseSyncTriggerTests` (#1154) — held
/// apart because that file reached the 350-line ceiling.
///
/// The dispatch fixed one of three gates. The other two — the
/// bot's own runs held at "Approve and run", and a merge queue
/// that will not take an auto-merge a bot armed — are cleared
/// by a real actor's token and by nothing in a workflow file,
/// so the job must thread ONE token through the push, the PR
/// and the arming, and must not leak it to a step that does not
/// need it.
@Suite("Release sync token")
struct ReleaseSyncTokenTests {
    @Test("One token pushes, opens and arms")
    func syncThreadsOneToken() throws {
        let yaml = try workflowSource("changelog.yml")
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        // ONE home, and it FALLS BACK: a repository with no
        // secret set must still open the PR it opens today.
        let declared = try #require(
            lines.first { $0.hasPrefix("SYNC_TOKEN:") },
            "changelog.yml declares no shared token (#1154)"
        )
        #expect(
            declared.contains("secrets.RELEASE_SYNC_TOKEN")
                && declared.contains("github.token"),
            """
            the token declaration has no fallback — a repository \
            without the secret would push with nothing
            """
        )
        // What fires `pull_request` is who PUSHED, so the
        // checkout takes it too. Guarding only `GH_TOKEN` would
        // leave a real actor opening a PR on a branch the bot
        // pushed, which reports nothing.
        // Scoped to the checkout by NAME: read file-wide, any
        // future step spelling that key satisfies this with the
        // pushing checkout's token removed.
        let checkout = try workflowStep(
            "Check out main with the token that will push",
            in: yaml
        )
        #expect(
            checkout.contains("token: ${{ env.SYNC_TOKEN"),
            "the checkout does not carry the shared token"
        )
        // Every `gh` step reads that one home rather than
        // spelling a token of its own — the coupling an edit
        // breaks silently, since a `github.token` step still
        // runs and still opens a PR that strands.
        let spellings = lines.filter { $0.hasPrefix("GH_TOKEN:") }
        #expect(
            !spellings.isEmpty,
            "changelog.yml runs `gh` with no token at all"
        )
        for spelling in spellings {
            #expect(
                spelling.contains("env.SYNC_TOKEN"),
                """
                `\(spelling)` names a token of its own — the PR \
                is only as good as the weakest step that made it
                """
            )
        }
    }

    @Test("Every step consumes the token or shadows it")
    func noStepInheritsTheTokenSilently() throws {
        let yaml = try workflowSource("changelog.yml")
        let steps = Self.steps(in: yaml)
        try #require(
            steps.count > 3,
            "the sync job's steps did not parse — this reads nothing"
        )
        for step in steps {
            let consumes = step.contains("env.SYNC_TOKEN")
            let shadows = step.contains("SYNC_TOKEN: \"\"")
            #expect(
                consumes != shadows,
                """
                a step neither consumes `SYNC_TOKEN` nor shadows \
                it. The job-level token is a REAL ACTOR's and \
                `permissions:` cannot narrow it, so every step \
                inherits it — including `npm ci`, which runs \
                lifecycle scripts from the whole site dependency \
                tree. Add `env: SYNC_TOKEN: ""` unless the step \
                needs it (#1154):
                \(step.split(separator: "\n").first ?? "")
                """
            )
        }
    }

    /// The sync job's steps, split on the `- ` that opens each.
    ///
    /// `workflowStep` needs a name and a step may have none, so
    /// this is the census half: it answers what steps EXIST
    /// rather than finding one that was looked for.
    static func steps(in yaml: String) -> [String] {
        var found: [String] = []
        var current: [Substring] = []
        for line in yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ) {
            if line.hasPrefix("      - ") {
                if !current.isEmpty {
                    found.append(current.joined(separator: "\n"))
                }
                current = [line]
            } else if !current.isEmpty {
                if !line.isEmpty, !line.hasPrefix("       ") {
                    found.append(current.joined(separator: "\n"))
                    current = []
                } else {
                    current.append(line)
                }
            }
        }
        if !current.isEmpty {
            found.append(current.joined(separator: "\n"))
        }
        return found
    }
}
