import Foundation
import Testing

/// The ship-grade copies of the verification gate against the
/// `verify-gate` skill that owns the procedure (#32, #487).
///
/// AGENTS.md §3 gives the skill the gate — "what to run, in what
/// order" — and two copies deliberately re-state it:
/// `scripts/release.sh`, because a release must not be cut on an
/// unverified tree, and the `verify` job in
/// `.github/workflows/release.yml`, because a tag pushed by hand
/// never met the script's gate and branch protection cannot see
/// tags. That makes the command list a hand-mirror, and
/// `.claude/rules/parity-tests.md` says a shipped mirror must
/// carry a parity test.
///
/// These are the mirrors where drift is worst: every other copy
/// of the gate merely reports, while a stale copy in either
/// ships an artifact. Adding a step to the skill and not to a
/// ship-grade copy silently narrows what a release is checked
/// against, and nothing else notices — the workflow copy cannot
/// even be exercised before a tag is live.
///
/// The expectation is **derived from the skill**, never listed
/// here — a hand-written copy in this file would be one more
/// place to forget, which is the failure the rule names.
@Suite("Release gate mirrors the verify-gate skill")
struct VerifyGateParityTests {
    @Test("every skill step runs in release.sh, in order")
    func gateMatchesSkill() throws {
        let steps = try skillSteps()
        // Guards the whole suite against passing vacuously if the
        // skill's markdown is reshaped and the scrape returns
        // nothing — the canary has to cover the collection the
        // assertions consume.
        #expect(
            steps.count >= 4,
            "scraped too few steps — has SKILL.md's list changed?"
        )
        #expect(steps.first == "swift build")

        let script = try String(
            contentsOf: Self.repoRoot
                .appendingPathComponent("scripts")
                .appendingPathComponent("release.sh"),
            encoding: .utf8
        )
        let lines = script.split(separator: "\n").map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        var searchFrom = 0
        for step in steps {
            let found = lines[searchFrom...].firstIndex {
                $0 == step || $0 == "./\(step)"
            }
            // One interpolated literal, never a `+` chain: the
            // message is a `Comment`, and a concatenation does
            // not convert to one.
            let at = try #require(
                found,
                "release.sh drifted from the skill: no `\(step)`"
            )
            searchFrom = at + 1
        }
    }

    @Test("every fast skill step runs in release.yml's verify job")
    func gateMatchesWorkflowVerifyJob() throws {
        // The fast inner loop only, by the skill's own section
        // structure — not a command-text filter, which would
        // silently exempt any future step that happened to
        // mention `-c release`. The conditional release build
        // binds release.sh alone: the release job must keep
        // that compile ahead of any submission or draft, and
        // packaging-and-release.md owns that obligation.
        let steps = try skillSteps(section: "Fast inner loop")
        // Guards this test's own collection: the section scope
        // narrows the scrape, so the count is re-asserted on
        // what THIS test iterates, not on the sibling's input.
        // 3 = build, test, lint since #494 collapsed the test
        // split; the sibling's canary covers the full list.
        #expect(
            steps.count >= 3,
            "scraped too few steps — has SKILL.md's list changed?"
        )

        let workflow = try String(
            contentsOf: Self.repoRoot
                .appendingPathComponent(".github")
                .appendingPathComponent("workflows")
                .appendingPathComponent("release.yml"),
            encoding: .utf8
        )
        let lines = workflow.split(
            separator: "\n",
            omittingEmptySubsequences: false
        ).map(String.init)
        // The job's slice, keyed on the 2-space job indentation
        // so a `needs: verify` elsewhere cannot match.
        let start = try #require(
            lines.firstIndex(of: "  verify:"),
            "release.yml has no `verify:` job"
        )
        let end = try #require(
            lines[start...].firstIndex(of: "  release:"),
            "release.yml has no `release:` job after `verify:`"
        )
        // A job key sits at exactly 2-space indent. One between
        // the boundaries would mean the slice absorbed a job
        // that is not `verify` — its commands would satisfy the
        // assertions below while the release job no longer
        // `needs:` them. The suffix is checked trimmed:
        // `bogus: ` with a trailing space is YAML-identical to
        // `bogus:` and must not slip past.
        let absorbed = lines[(start + 1)..<end].filter { line in
            line.hasPrefix("  ") && !line.hasPrefix("   ")
                && !line.hasPrefix("  #")
                && line.trimmingCharacters(in: .whitespaces)
                    .hasSuffix(":")
        }
        #expect(
            absorbed.isEmpty,
            "verify slice absorbed another job: \(absorbed)"
        )
        let slice = lines[start..<end].map {
            $0.trimmingCharacters(in: .whitespaces)
        }

        // Presence, not order: the job runs lint before the
        // tests (ci.yml's arrangement) while the skill lists
        // lint last, so the obligation here is the command SET.
        for step in steps {
            let present = slice.contains { line in
                line == step
                    || line == "./\(step)"
                    || line == "run: \(step)"
                    || line == "run: ./\(step)"
            }
            #expect(
                present,
                "verify job drifted from the skill: no `\(step)`"
            )
        }
    }

    /// The skill's numbered commands, in document order.
    ///
    /// Both its lists are scraped by default: the fast inner
    /// loop and the conditional release build. `release.sh` runs
    /// the release build unconditionally — its own comment
    /// argues why — so the skill's list is a subset obligation,
    /// not an equality. `section` narrows the scrape to one
    /// `## ` heading's list, which is how the workflow pin
    /// expresses its exemption structurally instead of by
    /// command text.
    private func skillSteps(
        section: String? = nil
    ) throws -> [String] {
        let skill = try String(
            contentsOf: Self.repoRoot
                .appendingPathComponent(".claude")
                .appendingPathComponent("skills")
                .appendingPathComponent("verify-gate")
                .appendingPathComponent("SKILL.md"),
            encoding: .utf8
        )
        var steps: [String] = []
        var heading = ""
        for raw in skill.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("## ") {
                heading = String(line.dropFirst(3))
                continue
            }
            guard section == nil || heading == section else {
                continue
            }
            // `1. \`swift build\`` — a numbered step whose command
            // is the first backticked span on the line.
            guard let dot = line.firstIndex(of: "."),
                line[..<dot].allSatisfy(\.isNumber),
                !line[..<dot].isEmpty,
                let open = line.firstIndex(of: "`")
            else { continue }
            let rest = line[line.index(after: open)...]
            guard let close = rest.firstIndex(of: "`") else {
                continue
            }
            var command = String(rest[..<close])
            // The skill parameterises the lint step; release.sh
            // lints the whole repo, which is the no-argument form.
            command = command.replacingOccurrences(
                of: " $ARGUMENTS",
                with: ""
            )
            steps.append(command)
        }
        return steps
    }

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }
}
