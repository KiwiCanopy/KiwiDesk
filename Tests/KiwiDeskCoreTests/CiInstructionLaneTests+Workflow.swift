import Foundation
import Testing

/// The workflow half of `CiInstructionLaneTests`: the `changes`
/// job's lane decision, run as shell, and the steps it swaps.
/// Split out under the §2.1 ceiling.
extension CiInstructionLaneTests {
    /// The `changes` job's path loop, lifted out of ci.yml and run
    /// with `EVENT`, `FILTER` and the changed paths, answering the
    /// `run` and `light` it writes.
    func decide(
        event: String,
        filter: String = "",
        changed: [String]
    ) throws -> (run: String, light: String) {
        let yaml = try String(
            contentsOf: repoRoot.appendingPathComponent(
                ".github/workflows/ci.yml"
            ),
            encoding: .utf8
        )
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0 == "          run=false" }
        )
        let end = try #require(
            lines[start...].firstIndex {
                $0.contains("echo \"light=$light\" >>")
            }
        )
        let body = lines[start...end].map { $0.dropFirst(10) }
            .joined(separator: "\n")
        let out = testTemporaryDirectory.appendingPathComponent(
            "lane-\(UUID().uuidString)"
        )
        let run = try spawn(
            "/bin/bash",
            [
                "-c",
                "set -euo pipefail\nchanged=\"$CHANGED\"\n" + body,
            ],
            environment: [
                "EVENT": event, "FILTER": filter,
                "CHANGED": changed.joined(separator: "\n"),
                "GITHUB_OUTPUT": out.path,
                "PATH": "/usr/bin:/bin",
            ],
            currentDirectory: repoRoot
        )
        try #require(run.status == 0, "\(run.stderr)")
        let text = try String(contentsOf: out, encoding: .utf8)
        func value(_ key: String) -> String {
            text.split(separator: "\n")
                .first { $0.hasPrefix("\(key)=") }
                .map { String($0.dropFirst(key.count + 1)) } ?? ""
        }
        return (value("run"), value("light"))
    }

    @Test("only a pull request or a filtered dispatch takes the lane")
    func laneDecision() throws {
        let rule = [".claude/rules/gui.md"]
        let agents = ["AGENTS.md", ".claude/agents/x.md"]
        let mixed = [".claude/rules/gui.md", "Sources/KiwiDesk/x.swift"]
        // An ignored path read off the list, since a literal one
        // here would read as this suite reading it.
        let exact = try CiPathFilterTests().entries()
            .first { !$0.hasSuffix("/**") }
        let ignored = [".claude/rules/gui.md", try #require(exact)]
        #expect(
            try decide(event: "pull_request", changed: rule) == (
                "false", "true"
            )
        )
        #expect(
            try decide(event: "pull_request", changed: agents) == (
                "false", "true"
            )
        )
        #expect(
            try decide(event: "pull_request", changed: ignored) == (
                "false", "true"
            )
        )
        #expect(
            try decide(event: "pull_request", changed: mixed) == (
                "true", "false"
            )
        )
        #expect(
            try decide(event: "pull_request", changed: mixed.reversed())
                == ("true", "false")
        )
        // main's push run stays the full-suite backstop.
        #expect(try decide(event: "push", changed: rule) == ("true", "false"))
        #expect(
            try decide(
                event: "workflow_dispatch",
                filter: "true",
                changed: rule
            )
                == ("false", "true")
        )
        #expect(
            try decide(
                event: "workflow_dispatch",
                filter: "false",
                changed: rule
            )
                == ("true", "false")
        )
    }

    @Test("ci.yml picks the lane in the changes job and swaps the tests")
    func workflowRunsTheLane() throws {
        let yaml = try workflowSource("ci.yml")
        let changes = try #require(
            CiPathFilterTests.jobBlock("changes", in: yaml)
        )
        #expect(changes.contains("light: ${{ steps.filter.outputs.light }}"))
        // The lane's paths exactly: a wider arm puts paths on the
        // lane that no reader scan covers.
        let arms = changes.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasSuffix(")") && $0.contains(".claude") }
        #expect(arms == [".claude/*|AGENTS.md)"])
        #expect(
            changes.contains(
                "AGENTS.md)\n"
                    + "                  echo \"instruction file: $file\"\n"
                    + "                  light=true\n"
            )
        )
        // A push keeps the full run; renames name both ends.
        #expect(changes.contains("pull_request) lane=true ;;"))
        #expect(changes.contains("if [ \"$lane\" = true ]; then"))
        #expect(
            changes.components(separatedBy: "--name-only --no-renames")
                .count == 3
        )
        #expect(
            changes.contains("echo \"light=$light\" >> \"$GITHUB_OUTPUT\"")
        )
        // A path outside the lane clears it, or a mixed change
        // would run the readers alone.
        let decide = try workflowStep(
            "Decide whether the build jobs must run",
            in: yaml
        )
        let other = try #require(decide.range(of: "run=true\n"))
        #expect(
            decide[other.upperBound...].hasPrefix(
                "            light=false\n            break"
            )
        )
        for name in ["Test", "Test (ExecTests)"] {
            let step = try workflowStep(name, in: yaml)
            #expect(
                step.contains("if: needs.changes.outputs.light != 'true'"),
                "\(name) must run unless the lane was picked"
            )
        }
        let readers = try workflowStep("Instruction readers", in: yaml)
        #expect(readers.contains("if: needs.changes.outputs.light == 'true'"))
        #expect(
            readers.contains("filter=\"$(scripts/ci-instruction-filter)\"")
        )
        #expect(readers.contains("swift test --filter \"$filter\""))
        // The release build stays off the lane: nothing it builds
        // reads an instruction file.
        let release = CiPathFilterTests.jobGate("release-build", in: yaml)
        #expect(release?.contains("light") == false)
    }

}
