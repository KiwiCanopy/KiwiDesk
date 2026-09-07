import Foundation
import Testing

/// The release sync PR must be able to land without a human.
///
/// `.github/workflows/changelog.yml` opens its PR with
/// `GITHUB_TOKEN`, and a PR opened with that token raises no
/// `pull_request` — so `ci.yml` reports neither of the two
/// contexts branch protection requires, and the PR sits BLOCKED
/// with nothing to press. Every release so far has needed a
/// human between publishing and the update feed going live
/// (#1154); packaging-and-release.md ▸ CI carries the argument.
///
/// Three couplings, each breakable by an edit that breaks
/// nothing else that reports: the dispatch and the grant it
/// needs; the arming, and its refusal to claim success without
/// asking; and the input NAME, one string across two files,
/// read off the dispatching side and required of the accepting
/// one.
///
/// Reads through `workflowSource` / `workflowStep` rather than a
/// local copy: both files argue this mechanism in prose that
/// names the very commands below, and the scoping is what stops
/// a needle being satisfied by a step that is not the one under
/// test (guard-prover and architect review, 2026-08-31).
///
/// Since #1154 was reopened all three gates are measured, on
/// v1.1.2's #1191: CI never reported (the dispatch fixes that),
/// the bot's own workflows sat at "Approve and run", and the
/// merge queue never took the auto-merge the bot armed. Only a
/// token belonging to a real actor clears the second and third,
/// so the job threads ONE token through the push, the PR and
/// the arming, and the dispatch — which exists only because
/// `github.token` fires nothing — stands down when that token
/// is present.
///
/// **What this cannot see**: whether the secret is actually
/// SET. A repository without `RELEASE_SYNC_TOKEN` falls back
/// and every clause below still passes, correctly — the
/// fallback is the shape being guarded, not the credential.
/// Only a real release answers whether the queue takes it.
@Suite("Release sync trigger")
struct ReleaseSyncTriggerTests {
    /// The step that opens, starts and arms, by its own name.
    static let prStep = "Open a PR if anything moved, and let it land"

    /// The `permissions:` block the sync job declares.
    ///
    /// Scoped, not file-wide: a permission granted to some other
    /// job would otherwise satisfy this one — the unscoped-needle
    /// failure `workflowStep` was extracted for, one level up
    /// (guard-prover, 2026-08-31).
    static func permissions(in yaml: String) -> [String] {
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        guard
            let start = lines.firstIndex(where: {
                $0.trimmingCharacters(in: .whitespaces)
                    == "permissions:"
            })
        else { return [] }
        let indent = lines[start].prefix { $0 == " " }.count
        var block: [String] = []
        for line in lines[(start + 1)...] {
            let trimmed = line.trimmingCharacters(
                in: .whitespaces
            )
            if trimmed.isEmpty { continue }
            let depth = line.prefix { $0 == " " }.count
            if depth <= indent { break }
            block.append(trimmed)
        }
        return block
    }

    /// Every input name the dispatch passes, read off its own
    /// `-f name=value`.
    ///
    /// Scoped to the dispatch command, and ALL of its inputs: a
    /// file-wide scan claims `git push -f`'s flag beside it, and
    /// a reader that stopped at the first passed while a second
    /// was declared nowhere and read nowhere (guard-prover,
    /// 2026-08-31). `workflowSource` has already joined the
    /// `\`-continuations, so the command is one line however the
    /// YAML wraps.
    static func dispatchedInputs(in command: String) -> [String] {
        var names: [String] = []
        var rest = Substring(command)
        while let flag = rest.range(of: "-f ") {
            let tail = rest[flag.upperBound...]
            guard let equals = tail.firstIndex(of: "=") else {
                break
            }
            names.append(
                String(tail[..<equals])
                    .trimmingCharacters(in: .whitespaces)
            )
            rest = tail[equals...]
        }
        return names
    }

    /// The `gh workflow run` line inside the PR step.
    ///
    /// Not `dispatchCommand`: `HoldGlideEligibilitySeamTests`
    /// counts that needle across both trees to hold `execute`'s
    /// tally to one caller, and a same-named helper here is a
    /// phantom second one.
    static func ciDispatchLine(in yaml: String) throws -> String {
        let step = try workflowStep(Self.prStep, in: yaml)
        return try #require(
            step.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first {
                    $0.contains("gh workflow run")
                        && $0.contains("ci.yml")
                },
            """
            changelog.yml no longer starts ci.yml — its PR raises \
            no pull_request, so nothing else ever will (#1154)
            """
        )
    }

    @Test("The sync workflow starts CI on the branch it pushed")
    func syncDispatchesCi() throws {
        let yaml = try workflowSource("changelog.yml")
        let started = try Self.ciDispatchLine(in: yaml)
        // On the branch, not on the default: a dispatch aimed at
        // `main` reports its checks against a commit the PR does
        // not carry — green in the Actions tab, and the PR
        // exactly as blocked.
        #expect(
            started.contains("--ref \"$BRANCH\""),
            "the dispatch is not aimed at the pushed branch"
        )
        #expect(
            Self.permissions(in: yaml).contains {
                $0.hasPrefix("actions: write")
            },
            """
            the sync job cannot dispatch a workflow without \
            `actions: write`
            """
        )
    }

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
        #expect(
            lines.contains {
                $0.hasPrefix("token: ${{ env.SYNC_TOKEN")
            },
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

    @Test("The hand-started CI stands down for a real token")
    func dispatchStandsDownForThePat() throws {
        let yaml = try workflowSource("changelog.yml")
        let lines = try workflowStep(Self.prStep, in: yaml)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let dispatch = try #require(
            lines.firstIndex {
                $0.contains("gh workflow run")
                    && $0.contains("ci.yml")
            },
            "the sync step no longer starts CI at all"
        )
        // The dispatch exists ONLY because `github.token` raises
        // no `pull_request`. Left unconditional, a real token
        // fires it too and two suites report the same required
        // contexts — a race over which verdict lands.
        #expect(
            lines[..<dispatch].contains {
                $0.contains("SYNC_TOKEN_IS_PAT")
            },
            """
            the CI dispatch is unconditional — with a real token \
            it duplicates the checks `pull_request` already \
            reports (#1154)
            """
        )
    }

    @Test("The PR it opens is armed to merge itself")
    func syncArmsAutoMerge() throws {
        let yaml = try workflowSource("changelog.yml")
        let lines = try workflowStep(Self.prStep, in: yaml)
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
        let armed = try #require(
            lines.firstIndex {
                $0.contains("gh pr merge") && $0.contains("--auto")
            },
            """
            changelog.yml opens a PR nobody merges — the feed goes \
            live only when it lands (#1154)
            """
        )
        let create = try #require(
            lines.firstIndex { $0.contains("gh pr create") },
            "changelog.yml no longer opens a PR"
        )
        // Auto-merge is armed on a PR, so it cannot precede the
        // call that makes one.
        #expect(
            create < armed,
            "auto-merge is armed before the PR exists"
        )
        // And a refused arming is not reported as a success: the
        // fallback path re-READS the PR rather than announcing
        // what it hoped for.
        #expect(
            lines.contains { $0.contains("autoMergeRequest") },
            """
            the arming failure path claims the PR is armed \
            without asking whether it is
            """
        )
    }

    @Test("Both files spell the dispatch inputs the same way")
    func dispatchInputsAreDeclared() throws {
        let sync = try workflowSource("changelog.yml")
        let ci = try workflowSource("ci.yml")
        let inputs = Self.dispatchedInputs(
            in: try Self.ciDispatchLine(in: sync)
        )
        try #require(
            !inputs.isEmpty,
            "changelog.yml passes no input to the CI dispatch"
        )
        let code = ci.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        .map { $0.trimmingCharacters(in: .whitespaces) }
        for input in inputs {
            // Declared, so `gh workflow run` is not silently
            // dropping it — the failure mode is a full macOS
            // build on every release rather than a red anything.
            #expect(
                code.contains { $0.hasPrefix("\(input):") },
                """
                ci.yml does not declare the `\(input)` input \
                that changelog.yml passes
                """
            )
            // And read where it decides, not merely declared: an
            // input nothing consults filters nothing, and a
            // declared one looks exactly as correct.
            #expect(
                code.contains { $0.contains("inputs.\(input)") },
                "ci.yml declares `\(input)` and never reads it"
            )
        }
    }
}
