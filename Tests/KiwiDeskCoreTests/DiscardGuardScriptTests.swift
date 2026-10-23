import Foundation
import Testing

/// `scripts/gate-hook` refuses a command that RUNS a script which
/// discards uncommitted tracked work: mutation drivers restoring
/// with `git checkout --` wiped fixes the inline snapshot never saw,
/// since the discard sat in the file, not the command. Each case
/// runs the hook against a throwaway repo holding a driver script.
@Suite("Gate hook refuses a discarding script on a dirty tree")
struct DiscardGuardScriptTests {
    private let shellDriver = "#!/bin/sh\ngit checkout -- a.txt\n"
    private let pythonDriver = """
        #!/usr/bin/env python3
        import subprocess
        subprocess.run(["git", "checkout", "--", "a.txt"])
        """

    @Test("a discarding script is refused while work is uncommitted")
    func dirtyScriptRefused() throws {
        for (driver, name, command) in [
            (shellDriver, "drive.sh", "./drive.sh"),
            (shellDriver, "drive.sh", "bash drive.sh"),
            (shellDriver, "drive.sh", "D=\"$REPO\"; $D/drive.sh"),
            (shellDriver, "drive.sh", "cd \"$REPO\" && zsh drive.sh"),
            (pythonDriver, "drive.py", "python3 drive.py"),
        ] {
            let repo = try makeRepo(dirty: true)
            defer { try? FileManager.default.removeItem(at: repo) }
            try write(driver, name, in: repo)
            let command = command.replacingOccurrences(
                of: "$REPO",
                with: repo.path
            )
            #expect(try decision(command, in: repo) == "deny", "\(command)")
            #expect(try contents(repo) == "changed\n")
        }
    }

    @Test("a committed tree lets the same script run")
    func cleanTreePasses() throws {
        let repo = try makeRepo(dirty: false)
        defer { try? FileManager.default.removeItem(at: repo) }
        try write(shellDriver, "drive.sh", in: repo)
        #expect(try decision("./drive.sh", in: repo) == nil)
    }

    @Test("a script that discards nothing passes a dirty tree")
    func harmlessScriptPasses() throws {
        let repo = try makeRepo(dirty: true)
        defer { try? FileManager.default.removeItem(at: repo) }
        try write("#!/bin/sh\ngit status\n", "drive.sh", in: repo)
        #expect(try decision("./drive.sh", in: repo) == nil)
        let mutate = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/mutate")
        #expect(try decision("\(mutate.path) s.json", in: repo) == nil)
    }

    /// A repo with `a.txt` committed, then modified when `dirty`.
    private func makeRepo(dirty: Bool) throws -> URL {
        let repo =
            testTemporaryDirectory
            .appendingPathComponent("discard-script-\(UUID())")
        try FileManager.default.createDirectory(
            at: repo,
            withIntermediateDirectories: true
        )
        try "a\n".write(
            to: repo.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        for args in [
            ["init", "-q"], ["add", "a.txt"],
            [
                "-c", "user.email=t@t", "-c", "user.name=t",
                "commit", "-qm", "init",
            ],
        ] {
            try spawn("/usr/bin/git", args, currentDirectory: repo)
        }
        if dirty {
            try "changed\n".write(
                to: repo.appendingPathComponent("a.txt"),
                atomically: true,
                encoding: .utf8
            )
        }
        return repo
    }

    private func write(_ text: String, _ name: String, in repo: URL) throws {
        let url = repo.appendingPathComponent(name)
        try text.write(to: url, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
    }

    private func contents(_ repo: URL) throws -> String {
        try String(
            contentsOf: repo.appendingPathComponent("a.txt"),
            encoding: .utf8
        )
    }

    /// The hook's `permissionDecision`, nil when it printed none.
    private func decision(_ command: String, in repo: URL) throws -> String? {
        let event: [String: Any] = [
            "tool_name": "Bash", "cwd": repo.path,
            "tool_input": ["command": command],
        ]
        let input =
            testTemporaryDirectory
            .appendingPathComponent("discard-script-\(UUID()).json")
        try JSONSerialization.data(withJSONObject: event)
            .write(to: input)
        defer { try? FileManager.default.removeItem(at: input) }
        let hook = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/gate-hook")
        let run = try spawn(
            "/bin/sh",
            ["-c", "exec python3 \"$0\" < \"$1\"", hook.path, input.path]
        )
        #expect(run.status == 0, "\(run.stderr)")
        guard !run.stdout.isEmpty else { return nil }
        let output = try #require(
            try JSONSerialization.jsonObject(
                with: Data(run.stdout.utf8)
            ) as? [String: Any]
        )
        let specific = output["hookSpecificOutput"] as? [String: Any]
        return specific?["permissionDecision"] as? String
    }
}
