import Foundation
import Testing

/// **`Build site` is required on `main` without stranding a PR that
/// leaves the site alone** (`.claude/rules/site.md`). The verdict
/// clauses run the `changes` step from `site.yml` against a throwaway
/// repository holding the real workflow, so they are the filter's own
/// answer and not a reading of its text.
@Suite("The site gate is required")
struct SiteGateRequiredTests {
    private static let stepName = "Decide whether the site must build"

    private static func git(
        _ arguments: [String],
        in repo: URL
    ) throws {
        let run = try spawn(
            "/usr/bin/git",
            [
                "-c", "user.name=t", "-c", "user.email=t@t", "-c",
                "commit.gpgsign=false",
            ] + arguments,
            currentDirectory: repo
        )
        try #require(run.status == 0, "git \(arguments): \(run.stderr)")
    }

    private static func write(
        _ text: String,
        to path: String,
        in repo: URL
    ) throws {
        let url = repo.appendingPathComponent(path)
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try text.write(to: url, atomically: true, encoding: .utf8)
    }

    /// The step's shell, its YAML indent removed.
    private static func filterScript() throws -> String {
        let step = try workflowStep(
            stepName,
            in: workflowSource("site.yml")
        )
        let lines = step.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let start = try #require(
            lines.firstIndex { $0.hasSuffix("run: |") },
            "the filter step has no run block"
        )
        return lines[(start + 1)...]
            .map { String($0.dropFirst(10)) }
            .joined(separator: "\n")
    }

    /// The `run` output for a PR that changes `paths`, or for the
    /// given event and base where a clause overrides them.
    private static func verdict(
        changing paths: [String],
        event: String = "pull_request",
        base: String? = nil,
        workflow: String? = nil
    ) throws -> String {
        let repo =
            testTemporaryDirectory
            .appendingPathComponent("site-gate-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: repo) }
        try FileManager.default.createDirectory(
            at: repo,
            withIntermediateDirectories: true
        )
        let real = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent(".github/workflows/site.yml"),
            encoding: .utf8
        )
        try git(["init", "-q"], in: repo)
        try write(
            workflow ?? real,
            to: ".github/workflows/site.yml",
            in: repo
        )
        try git(["add", "."], in: repo)
        try git(["commit", "-qm", "base"], in: repo)
        let baseSHA = try spawn(
            "/usr/bin/git",
            ["rev-parse", "HEAD"],
            currentDirectory: repo
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        for path in paths {
            try write("x\n", to: path, in: repo)
        }
        try git(["add", "."], in: repo)
        try git(["commit", "-qm", "head", "--allow-empty"], in: repo)
        let output = repo.appendingPathComponent("output.txt")
        let run = try spawn(
            "/bin/bash",
            ["-c", filterScript()],
            environment: [
                "EVENT": event,
                "BASE": base ?? baseSHA,
                "GITHUB_OUTPUT": output.path,
                "PATH": "/usr/bin:/bin",
            ],
            currentDirectory: repo
        )
        try #require(run.status == 0, "filter failed: \(run.stderr)")
        return try String(contentsOf: output, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @Test("A PR touching a site input builds")
    func inputsBuild() throws {
        for path in [
            "site/src/pages/index.astro",
            "docs/guide.md",
            "assets/AppIcon.icon/icon.json",
            "Sources/KiwiDesk/SupportLinks.swift",
            "ROADMAP.md",
            "scripts/unreleased-strip",
            ".github/workflows/site.yml",
        ] {
            #expect(
                try Self.verdict(changing: [path]) == "run=true",
                "\(path)"
            )
        }
        #expect(
            try Self.verdict(
                changing: ["Sources/KiwiDesk/Foo.swift", "site/a.astro"]
            ) == "run=true",
            "an input beside other paths must still build"
        )
    }

    @Test("A PR leaving the site alone skips, so it cannot strand")
    func othersSkip() throws {
        for path in [
            "Sources/KiwiDeskCore/State/Foo.swift",
            "Sources/KiwiDesk/SupportLinks.swift.orig",
            "scripts/unreleased-strip2",
            "sitemap/a.txt",
            "README.md",
        ] {
            #expect(
                try Self.verdict(changing: [path]) == "run=false",
                "\(path)"
            )
        }
    }

    @Test("Every unknown builds")
    func unknownsBuild() throws {
        #expect(
            try Self.verdict(changing: ["a.swift"], event: "push")
                == "run=true"
        )
        #expect(
            try Self.verdict(
                changing: ["a.swift"],
                base: String(repeating: "0", count: 40)
            ) == "run=true",
            "an unusable base must build"
        )
        #expect(
            try Self.verdict(changing: []) == "run=true",
            "an empty diff must build"
        )
        #expect(
            try Self.verdict(
                changing: ["a.swift"],
                workflow: "name: Site\n"
            ) == "run=true",
            "an empty input list must build"
        )
        #expect(
            try Self.verdict(
                changing: ["a.swift"],
                workflow: """
                    on:
                      push:
                        paths:
                          - "*.md"

                    """
            ) == "run=true",
            "an entry the filter cannot compare must build"
        )
    }

    @Test("The trigger reports on every PR and the skip is the job's")
    func wiring() throws {
        let yaml = try workflowSource("site.yml")
        let lines = yaml.split(separator: "\n").map(String.init)
        let trigger = try #require(
            lines.firstIndex { $0 == "  pull_request:" },
            "site.yml has no pull_request trigger"
        )
        #expect(
            !lines[trigger + 1].hasPrefix("    "),
            """
            site.yml filters pull_request at the trigger: a filtered \
            workflow never reports, so a required check waits forever
            """
        )
        let build = try #require(CiPathFilterTests.jobBlock("build", in: yaml))
        #expect(build.contains("needs: changes"))
        #expect(build.contains("name: Build site"))
        #expect(
            CiPathFilterTests.jobGate("build", in: yaml)
                == "!cancelled() && (needs.changes.result != "
                + "'success' || needs.changes.outputs.run == 'true')",
            "a failed filter must build, never skip (#1984)"
        )
    }

    @Test("protect-main requires the job by its display name")
    func protectMainRequiresIt() throws {
        let script = try String(
            contentsOf: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/protect-main.sh"),
            encoding: .utf8
        )
        let contexts = try #require(
            script.split(separator: "\n")
                .first { $0.hasPrefix("CONTEXTS=") }
        )
        #expect(contexts.contains("\"Build site\""))
    }
}
