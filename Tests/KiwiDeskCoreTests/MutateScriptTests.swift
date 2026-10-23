import Foundation
import Testing

/// `scripts/mutate` proves guards without losing uncommitted work:
/// it refuses a tree that differs from HEAD and restores every
/// mutated file from its own bytes. Each test runs the real script
/// in a throwaway git repository, with a `grep` standing in for the
/// test command so no `swift test` is spawned.
@Suite("Mutation harness")
struct MutateScriptTests {
    private let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts/mutate")

    /// A committed repo holding `a.txt` = "alpha\n" and a spec that
    /// mutates "alpha" to "beta".
    private func makeRepo() throws -> URL {
        let repo = testTemporaryDirectory.appendingPathComponent(
            "mutate-\(UUID().uuidString)"
        )
        try FileManager.default.createDirectory(
            at: repo,
            withIntermediateDirectories: true
        )
        try "alpha\n".write(
            to: repo.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        for args in [
            ["init", "-q"],
            ["add", "a.txt"],
            [
                "-c", "user.name=t", "-c", "user.email=t@t",
                "commit", "-qm", "seed",
            ],
        ] {
            try spawn("/usr/bin/git", args, currentDirectory: repo)
        }
        let spec = """
            [{"name": "alpha off", "file": "a.txt", "old": "alpha",
              "new": "beta", "filter": "alpha"}]
            """
        try spec.write(
            to: repo.appendingPathComponent("spec.json"),
            atomically: true,
            encoding: .utf8
        )
        return repo
    }

    private func run(_ repo: URL, testCmd: String) throws -> ScriptRun {
        try spawn(
            "/usr/bin/env",
            [
                "python3", script.path, "spec.json",
                "--test-cmd", testCmd,
            ],
            currentDirectory: repo
        )
    }

    private func contents(_ repo: URL) throws -> String {
        try String(
            contentsOf: repo.appendingPathComponent("a.txt"),
            encoding: .utf8
        )
    }

    @Test("an uncommitted edit refuses the run and survives it")
    func dirtyTreeRefuses() throws {
        let repo = try makeRepo()
        try "alpha\nwork in progress\n".write(
            to: repo.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        let result = try run(repo, testCmd: "grep -q {filter} a.txt")
        #expect(result.status == 2)
        #expect(result.stderr.contains("refusing to mutate"))
        #expect(try contents(repo) == "alpha\nwork in progress\n")
    }

    @Test("a guard that reds is reported and the file restored")
    func redGuardRestores() throws {
        let repo = try makeRepo()
        let result = try run(repo, testCmd: "grep -q {filter} a.txt")
        #expect(result.status == 0, "\(result.stderr)")
        #expect(result.stdout.contains("alpha off  red"))
        #expect(try contents(repo) == "alpha\n")
    }

    @Test("a guard that stays green fails the run, file restored")
    func greenGuardFails() throws {
        let repo = try makeRepo()
        let result = try run(repo, testCmd: "true")
        #expect(result.status == 1)
        #expect(result.stdout.contains("alpha off  GREEN"))
        #expect(try contents(repo) == "alpha\n")
    }

    @Test("a baseline that is already red refuses to prove")
    func redBaselineRefuses() throws {
        let repo = try makeRepo()
        let result = try run(repo, testCmd: "false")
        #expect(result.status == 3)
        #expect(try contents(repo) == "alpha\n")
    }
}
