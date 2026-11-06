import Foundation
import Testing

/// `ci.yml` splits the test targets across jobs behind one required
/// context (packaging-and-release.md ▸ CI). Two failures stay green
/// otherwise: a test target no job builds, and a skipped job passing
/// the check with nothing run (#1984).
@Suite("CI's required test jobs")
struct CiRequiredJobTests {
    /// Every step that compiles under the ratchet beside `Build`.
    static let ratchetedTestSteps = [
        "Test (GUI)", "Test (GUI ExecTests)",
        "Test (Core)", "Test (Core ExecTests)",
        "Instruction readers",
    ]

    /// The package's test targets, read from the manifest so a new
    /// one is owed a job.
    private func testTargets() throws -> [String] {
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

    @Test("every test target runs in both partitions of one job")
    func everyTargetHasAJob() throws {
        let yaml = try workflowSource("ci.yml")
        let jobs = ["test-gui", "test-core"]
            .compactMap { CiPathFilterTests.jobBlock($0, in: yaml) }
        try #require(jobs.count == 2)
        for target in try testTargets() {
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

    @Test("the required context is the judge, over every test job")
    func requiredContextJudges() throws {
        let yaml = try workflowSource("ci.yml")
        let judge = try #require(
            CiPathFilterTests.jobBlock("build-lint-test", in: yaml)
        )
        #expect(judge.contains("name: Build, Lint & Test\n"))
        #expect(judge.contains("if: ${{ !cancelled() }}"))
        #expect(
            judge.contains(
                "needs: [changes, test-gui, test-core, instruction-readers]"
            )
        )
        let protect = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/protect-main.sh"),
            encoding: .utf8
        )
        #expect(protect.contains("\"Build, Lint & Test\""))
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
        let step = try workflowStep(
            "Judge the test jobs",
            in: try workflowSource("ci.yml")
        )
        let lines = step.split(
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
        // A skip where the run was owed, and each losing result.
        #expect(try !judges(gui: "skipped"))
        #expect(try !judges(core: "skipped"))
        #expect(try !judges(gui: "failure"))
        #expect(try !judges(core: "cancelled"))
        #expect(try !judges(readers: "failure"))
    }
}
