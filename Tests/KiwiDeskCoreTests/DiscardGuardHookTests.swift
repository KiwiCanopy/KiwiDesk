import Foundation
import Testing

/// `scripts/gate-hook` snapshots uncommitted work before a git
/// command that discards it (owner ruling 2026-10-07): nine
/// recorded wipes of uncommitted fixes by a `git checkout --`
/// restore. Each case runs the hook against a throwaway repo
/// with a modified tracked file and an untracked one.
@Suite("Gate hook snapshots work before a discard")
struct DiscardGuardHookTests {
    @Test("a discarding command pins the modified work")
    func discardIsSnapshotted() throws {
        for command in [
            "git checkout -- a.txt",
            "git checkout HEAD -- a.txt",
            "git checkout .",
            "git checkout a.txt",
            "git checkout -f main",
            "git checkout -qf main",
            "git switch --discard-changes main",
            "git switch -f main",
            "git restore -W a.txt",
            "git stash && swift test --filter X",
            "git --no-pager -c a.b=c checkout -- a.txt",
            "FOO=1 git reset --hard",
            "git -C . restore a.txt",
            "git restore --staged --worktree a.txt",
            "git reset --hard",
            "git stash",
            "git stash -u",
            "cd . && git stash push -u",
        ] {
            let repo = try makeRepo()
            defer { try? FileManager.default.removeItem(at: repo) }
            let note = try hookNote(command, in: repo)
            #expect(
                note?.contains("refs/discard-backups/") == true,
                "\(command)"
            )
            let refs = try git(
                repo,
                "for-each-ref",
                "--format=%(refname)",
                "refs/discard-backups/"
            )
            let ref = try #require(
                refs.split(separator: "\n").first,
                "\(command)"
            )
            #expect(try git(repo, "show", "\(ref):a.txt") == "changed")
            #expect(try git(repo, "stash", "list").isEmpty)
        }
    }

    @Test("the snapshot is taken where the command acts")
    func snapshotFollowsTheTarget() throws {
        let elsewhere = try makeRepo()
        defer { try? FileManager.default.removeItem(at: elsewhere) }
        for command in [
            "git -C \"$REPO\" checkout -- a.txt",
            "cd \"$REPO\" && git checkout -- a.txt",
        ] {
            let repo = try makeRepo()
            defer { try? FileManager.default.removeItem(at: repo) }
            let spelled = command.replacingOccurrences(
                of: "$REPO",
                with: repo.path
            )
            _ = try hookNote(spelled, in: elsewhere)
            #expect(
                !(try git(repo, "for-each-ref", "refs/discard-backups/")
                    .isEmpty),
                "\(command)"
            )
        }
        #expect(
            try git(elsewhere, "for-each-ref", "refs/discard-backups/")
                .isEmpty
        )
    }

    @Test("two worktrees of one repo keep a snapshot each")
    func worktreesDoNotCollide() throws {
        let repo = try makeRepo()
        let other = repo.deletingLastPathComponent()
            .appendingPathComponent(repo.lastPathComponent + "-wt")
        defer {
            try? FileManager.default.removeItem(at: repo)
            try? FileManager.default.removeItem(at: other)
        }
        try git(repo, "worktree", "add", "-q", "--detach", other.path)
        try "other\n".write(
            to: other.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        let command =
            "git -C \"\(repo.path)\" reset --hard; "
            + "git -C \"\(other.path)\" reset --hard"
        _ = try hookNote(command, in: repo)
        let refs = try git(
            repo,
            "for-each-ref",
            "--format=%(refname)",
            "refs/discard-backups/"
        )
        #expect(refs.split(separator: "\n").count == 2)
    }

    @Test("a forced clean keeps every untracked file")
    func cleanKeepsUntracked() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        try "ü\n".write(
            to: repo.appendingPathComponent("ü b.txt"),
            atomically: true,
            encoding: .utf8
        )
        let note = try #require(try hookNote("git clean -fd", in: repo))
        let marker = "untracked files in "
        try #require(note.contains(marker))
        let tarball = try #require(
            note.components(separatedBy: marker).last
        )
        // A non-UTF-8 locale makes `tar -t` escape the name.
        let listed = try spawn(
            "/usr/bin/tar",
            ["-tf", tarball],
            environment: ["LC_ALL": "en_US.UTF-8"]
        ).stdout
        #expect(listed.contains("u.txt"))
        #expect(listed.contains("ü b.txt"))
    }

    @Test("a command that discards nothing leaves no snapshot")
    func otherCommandsPassThrough() throws {
        for command in [
            "git status", "git checkout -b x", "git checkout main",
            "git checkout --detach HEAD", "git restore --staged a.txt",
            "git restore -S a.txt", "grep -n \"git checkout -- a\" f",
            "git stash list", "git stash apply x", "git clean -n -f",
            "git clean --dry-run --force",
            "git stash -q pop",
            "git checkout no-such-path",
        ] {
            let repo = try makeRepo()
            defer { try? FileManager.default.removeItem(at: repo) }
            _ = try hookNote(command, in: repo)
            #expect(
                try git(repo, "for-each-ref", "refs/discard-backups/")
                    .isEmpty,
                "\(command)"
            )
        }
    }

    @Test("a clean tree takes no snapshot")
    func cleanTreeTakesNone() throws {
        let repo = try makeRepo()
        defer { try? FileManager.default.removeItem(at: repo) }
        _ = try git(repo, "checkout", "--", "a.txt")
        try FileManager.default.removeItem(
            at: repo.appendingPathComponent("u.txt")
        )
        #expect(try hookNote("git checkout -- a.txt", in: repo) == nil)
    }

    /// A repo with `a.txt` committed then modified, and an
    /// untracked `u.txt`.
    private func makeRepo() throws -> URL {
        let repo = FileManager.default.temporaryDirectory
            .appendingPathComponent("discard-guard-\(UUID())")
        try FileManager.default.createDirectory(
            at: repo,
            withIntermediateDirectories: true
        )
        _ = try git(repo, "init", "-q")
        try "a\n".write(
            to: repo.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        _ = try git(repo, "add", "a.txt")
        _ = try git(
            repo,
            "-c",
            "user.email=t@t",
            "-c",
            "user.name=t",
            "commit",
            "-qm",
            "init"
        )
        try "changed\n".write(
            to: repo.appendingPathComponent("a.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "u\n".write(
            to: repo.appendingPathComponent("u.txt"),
            atomically: true,
            encoding: .utf8
        )
        return repo
    }

    @discardableResult
    private func git(_ repo: URL, _ args: String...) throws -> String {
        let run = try spawn("/usr/bin/git", args, currentDirectory: repo)
        return run.stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// The hook's `systemMessage`, nil when it printed none.
    private func hookNote(
        _ command: String,
        in repo: URL
    ) throws -> String? {
        let event: [String: Any] = [
            "tool_name": "Bash", "cwd": repo.path,
            "tool_input": ["command": command],
        ]
        let input = FileManager.default.temporaryDirectory
            .appendingPathComponent("discard-hook-\(UUID()).json")
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
        return output["systemMessage"] as? String
    }
}
