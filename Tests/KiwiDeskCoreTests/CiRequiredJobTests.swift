import Foundation
import Testing

/// `ci.yml` splits the test targets across jobs behind one required
/// context (packaging-and-release.md ▸ CI). What stays green without
/// this: a test target no job builds, a test job whose red no check
/// reads, and a skipped job passing the check with nothing run
/// (#1984).
@Suite("CI's required test jobs")
struct CiRequiredJobTests {
    private static let judge = "build-lint-test"

    /// Every step that runs `swift test`, read from the workflow so a
    /// new one is owed the ratchet (`WarningRatchetWorkflowTests`,
    /// `WarningGateTests`).
    static func testSteps(in yaml: String) throws -> [String] {
        let names = yaml.split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.hasPrefix("- name: ") }
            .map { String($0.dropFirst("- name: ".count)) }
        let steps = try names.filter {
            try workflowStep($0, in: yaml).contains("swift test")
        }
        try #require(!steps.isEmpty, "no test step read")
        // `workflowStep` finds a name's first step and reads no unnamed
        // one, so either shape would escape every reader of this list.
        try #require(
            Set(steps).count == steps.count,
            "two test steps share a name"
        )
        try #require(
            yaml.components(separatedBy: "swift test").count - 1
                == steps.count,
            "a step runs `swift test` this list cannot read"
        )
        return steps
    }

    /// The package's test targets, read from the manifest so a new
    /// one is owed a job.
    static func testTargets() throws -> [String] {
        let manifest = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let names = manifest.components(separatedBy: ".testTarget(")
            .dropFirst()
            .compactMap { piece -> String? in
                let parts = piece.components(separatedBy: "\"")
                return parts.count > 1 ? parts[1] : nil
            }
        try #require(!names.isEmpty, "no test target read")
        return names
    }

    /// The contexts the ruleset requires, off the assignment itself:
    /// the script's prose names them too.
    private func requiredContexts() throws -> [String] {
        let protect = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/protect-main.sh"),
            encoding: .utf8
        )
        let line = try #require(
            protect.split(separator: "\n")
                .first { $0.hasPrefix("CONTEXTS='") }
        )
        return line.components(separatedBy: "\"").enumerated()
            .filter { $0.offset % 2 == 1 }.map(\.element)
    }

    private func judgeStep() throws -> String {
        try workflowStep(
            "Judge the test jobs",
            in: try workflowSource("ci.yml")
        )
    }

    @Test("every test target runs in both partitions of one job")
    func everyTargetHasAJob() throws {
        let yaml = try workflowSource("ci.yml")
        let jobs = CiPathFilterTests.jobIDs(in: yaml).compactMap {
            CiPathFilterTests.jobBlock($0, in: yaml)
        }
        try #require(!jobs.isEmpty, "no job read")
        for target in try Self.testTargets() {
            let product = "--test-product \(target) "
            let owners = jobs.filter {
                $0.contains(product + "--skip ExecTests")
                    && $0.contains(product + "--filter ExecTests")
            }
            #expect(
                owners.count == 1,
                "\(target) must run in exactly one test job"
            )
        }
    }

    @Test("the required context is the judge, running whatever they did")
    func requiredContextJudges() throws {
        let yaml = try workflowSource("ci.yml")
        let block = try #require(
            CiPathFilterTests.jobBlock(Self.judge, in: yaml)
        )
        #expect(block.contains("\n    name: Build, Lint & Test\n"))
        // Job level: on a step, a failed need skips the judge, and
        // the skip passes the required check.
        #expect(
            CiPathFilterTests.jobGate(Self.judge, in: yaml)
                == "!cancelled()"
        )
        #expect(try requiredContexts().contains("Build, Lint & Test"))
        // The same hazard one level in: a second `if` on the step
        // skips the verdict while the job still reports.
        let conditions = block.split(separator: "\n").filter {
            $0.trimmingCharacters(in: .whitespaces).hasPrefix("if:")
        }
        #expect(conditions.count == 1, "the judge's verdict is conditional")
        // A job or step so marked reports `success` whatever it did.
        #expect(!yaml.contains("continue-on-error"))
    }

    /// A gated job whose red nothing required reads merges anyway. The
    /// test injects the judge's environment, so the wiring from each
    /// job's result into it is held here. Trade: the verdict's read is
    /// a text match, so a key only echoed passes; `judgeFailsClosed`
    /// holds the keys it injects.
    @Test("the judge reads every gated job that is no required context")
    func judgeCoversEveryGatedJob() throws {
        let yaml = try workflowSource("ci.yml")
        let required = try requiredContexts()
        let block = try #require(
            CiPathFilterTests.jobBlock(Self.judge, in: yaml)
        )
        let needsLine = try #require(
            block.split(separator: "\n")
                .first { $0.hasPrefix("    needs: [") }
        )
        let needs = needsLine.dropFirst("    needs: [".count).dropLast()
            .components(separatedBy: ", ")
        let step = try judgeStep()
        // Every job but the filter and the judge, however it is gated.
        let gated = CiPathFilterTests.jobIDs(in: yaml).filter {
            if $0 == "changes" || $0 == Self.judge { return false }
            let body = CiPathFilterTests.jobBlock($0, in: yaml) ?? ""
            let name = body.split(separator: "\n")
                .first { $0.hasPrefix("    name: ") }?
                .dropFirst("    name: ".count)
            return !required.contains(String(name ?? ""))
        }
        try #require(gated.count > 1, "no gated job read")
        for job in gated {
            #expect(needs.contains(job), "the judge does not need \(job)")
            let wire = try #require(
                step.split(separator: "\n").first {
                    $0.hasSuffix("${{ needs.\(job).result }}")
                },
                "the judge's environment does not read \(job)"
            )
            let key = wire.trimmingCharacters(in: .whitespaces)
                .prefix { $0 != ":" }
            #expect(
                step.contains("\"$\(key)\""),
                "the judge's verdict does not read \(key)"
            )
        }
        #expect(
            step.contains("CHANGES: ${{ needs.changes.result }}"),
            "the judge does not read the filter's result"
        )
        #expect(step.contains("RUN: ${{ needs.changes.outputs.run }}"))
        #expect(step.contains("LIGHT: ${{ needs.changes.outputs.light }}"))
    }

    /// The judge's shell, lifted out of ci.yml and run.
    private func judges(
        changes: String = "success",
        run: String = "true",
        light: String = "false",
        gui: String = "success",
        core: String = "success",
        readers: String = "skipped"
    ) throws -> Bool {
        let lines = try judgeStep().split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0.contains("run: |") }
        )
        let body = lines[(start + 1)...].map { $0.dropFirst(10) }
            .joined(separator: "\n")
        try #require(body.contains("exit 1"), "empty judge")
        let result = try spawn(
            "/bin/bash",
            ["-e", "-c", body],
            environment: [
                "CHANGES": changes, "RUN": run, "LIGHT": light,
                "GUI": gui, "CORE": core, "READERS": readers,
                "PATH": "/usr/bin:/bin",
            ]
        )
        return result.status == 0
    }

    @Test("the judge passes only what the filter's answer owed")
    func judgeFailsClosed() throws {
        #expect(try judges())
        // The filter skipped everything: an ignored-only change.
        #expect(
            try judges(
                run: "false",
                gui: "skipped",
                core: "skipped"
            )
        )
        // A release stamp answers `run=false` and leaves `light` empty.
        #expect(
            try judges(
                run: "false",
                light: "",
                gui: "skipped",
                core: "skipped"
            )
        )
        // The instruction lane.
        #expect(
            try judges(
                run: "false",
                light: "true",
                gui: "skipped",
                core: "skipped",
                readers: "success"
            )
        )
        #expect(
            try !judges(
                run: "false",
                light: "true",
                gui: "skipped",
                core: "skipped"
            )
        )
        // A failed filter owes the full run (#1984).
        #expect(try judges(changes: "failure", run: ""))
        #expect(
            try !judges(
                changes: "failure",
                run: "",
                gui: "skipped",
                core: "skipped"
            )
        )
        #expect(
            try !judges(
                changes: "failure",
                run: "false",
                gui: "skipped",
                core: "skipped"
            )
        )
        // A filter that lost its answer: every unknown means run.
        #expect(
            try !judges(
                run: "",
                light: "",
                gui: "skipped",
                core: "skipped"
            )
        )
        // A skip where the run was owed, and each losing result.
        #expect(try !judges(gui: "skipped"))
        #expect(try !judges(core: "skipped"))
        #expect(try !judges(gui: "failure"))
        #expect(try !judges(core: "cancelled"))
        #expect(try !judges(readers: "failure"))
        #expect(try !judges(readers: "cancelled"))
    }
}
