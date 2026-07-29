import Foundation
import Testing

/// `scripts/release.sh`'s verification gate against the
/// `verify-gate` skill that owns the procedure (#32).
///
/// AGENTS.md §3 gives the skill the gate — "what to run, in what
/// order" — and `release.sh` deliberately re-states it, because
/// CI cannot run and a release must not be cut on an unverified
/// tree. That makes the command list a hand-mirror, and
/// `.claude/rules/parity-tests.md` says a shipped mirror must
/// carry a parity test.
///
/// This is the mirror where drift is worst: every other copy of
/// the gate merely reports, while a stale copy *here* ships an
/// artifact. Adding a step to the skill and not to `release.sh`
/// silently narrows what a release is checked against, and
/// nothing else notices.
///
/// The expectation is **derived from the skill**, never listed
/// here — a hand-written copy in this file would be a third
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

    /// The skill's numbered commands, in document order.
    ///
    /// Both its lists are scraped: the fast inner loop and the
    /// conditional release build. `release.sh` runs the release
    /// build unconditionally — its own comment argues why — so
    /// the skill's list is a subset obligation, not an equality.
    private func skillSteps() throws -> [String] {
        let skill = try String(
            contentsOf: Self.repoRoot
                .appendingPathComponent(".claude")
                .appendingPathComponent("skills")
                .appendingPathComponent("verify-gate")
                .appendingPathComponent("SKILL.md"),
            encoding: .utf8
        )
        var steps: [String] = []
        for raw in skill.split(separator: "\n") {
            let line = raw.trimmingCharacters(in: .whitespaces)
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
