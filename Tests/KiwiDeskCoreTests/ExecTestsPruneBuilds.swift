import Foundation
import Testing

/// `scripts/prune-builds` deletes build output only in a worktree
/// that passes every clause of its predicate (#3186), and
/// `scripts/gate-lock` runs it when the disk is low. Each case runs
/// the real scripts on a fixture repository with worktrees of its
/// own and a gate lock of its own, never the developer's. Named
/// into the `ExecTests` partition: it holds real child processes.
@Suite("prune-builds clears only idle, unused worktrees")
struct ExecTestsPruneBuilds {
    @Test("an idle tree is cleared, the caller's own is kept")
    func idleTreeClearedOwnTreeKept() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let run = try desk.prune(from: desk.tree("a"))
        #expect(run.status == 0, "\(run.stderr)")
        #expect(desk.hasOutput(desk.tree("a")), "own tree cleared")
        #expect(!desk.hasOutput(desk.tree("b")), "\(run.stdout)")
        #expect(!desk.hasOutput(desk.repo), "\(run.stdout)")
    }

    @Test("a dry run deletes nothing")
    func dryRunDeletesNothing() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let run = try desk.prune(from: desk.repo, apply: false)
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("would"), "\(run.stdout)")
        #expect(desk.hasOutput(desk.tree("b")))
    }

    @Test("nothing goes while another process holds the gate")
    func heldGateClearsNothing() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let holder = try desk.hold(
            "/usr/bin/lockf",
            ["-k", desk.lock.path, "/bin/cat"]
        )
        defer { holder.release() }
        try desk.waitUntilGateHeld()
        let run = try desk.prune(from: desk.repo)
        #expect(run.status == 75, "\(run.stdout)\(run.stderr)")
        #expect(desk.hasOutput(desk.tree("a")))
        #expect(desk.hasOutput(desk.tree("b")))
    }

    @Test("a tree a process has its cwd inside is kept")
    func processCwdKeepsTree() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let deep = desk.tree("b").appendingPathComponent(".build/out")
        let holder = try desk.hold("/bin/cat", [], in: deep)
        defer { holder.release() }
        let run = try desk.prune(from: desk.repo)
        #expect(run.status == 0, "\(run.stderr)")
        #expect(desk.hasOutput(desk.tree("b")), "\(run.stdout)")
        #expect(!desk.hasOutput(desk.tree("a")), "\(run.stdout)")
    }

    @Test("a tree built within the idle window is kept")
    func recentBuildKeepsTree() throws {
        let desk = try PruneDesk(freshTree: "b")
        defer { desk.remove() }
        let run = try desk.prune(from: desk.repo)
        #expect(run.status == 0, "\(run.stderr)")
        #expect(desk.hasOutput(desk.tree("b")), "\(run.stdout)")
        #expect(!desk.hasOutput(desk.tree("a")), "\(run.stdout)")
    }

    /// The trigger itself: gate-lock prunes on low disk, inside its
    /// own lock, and never on the nested path.
    @Test("gate-lock prunes on low disk, never when nested")
    func gateLockTriggersPrune() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let nested = try desk.gateLock(lowDisk: true, nested: true)
        #expect(nested.status == 0, "\(nested.stderr)")
        #expect(desk.hasOutput(desk.tree("a")), "nested path pruned")
        let roomy = try desk.gateLock(lowDisk: false)
        #expect(roomy.status == 0, "\(roomy.stderr)")
        #expect(desk.hasOutput(desk.tree("a")), "pruned with room")
        let low = try desk.gateLock(lowDisk: true)
        #expect(low.status == 0, "\(low.stderr)")
        #expect(low.stdout == "gated\n", "\(low.stdout)")
        #expect(!desk.hasOutput(desk.tree("a")), "\(low.stderr)")
    }
}

/// A process the test keeps alive until `release`: `cat` on an open
/// pipe exits when the pipe closes.
private struct Holder {
    let process: Process
    let input: Pipe

    func release() {
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()
    }
}

/// A fixture repository with worktrees `a` and `b`, each holding a
/// `.build` whose markers are two days old.
private struct PruneDesk {
    let root: URL
    var repo: URL { root.appendingPathComponent("repo") }
    var lock: URL {
        root.appendingPathComponent("gate/kiwidesk-gate.lock")
    }

    init(freshTree: String? = nil) throws {
        root =
            testTemporaryDirectory
            .appendingPathComponent("prune-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        let files = FileManager.default
        for dir in ["repo", "gate", "home"] {
            try files.createDirectory(
                at: root.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }
        try git(["init", "-q"])
        try git([
            "-c", "user.name=t", "-c", "user.email=t@t",
            "commit", "-q", "--allow-empty", "-m", "x",
        ])
        for name in ["a", "b"] {
            try git([
                "worktree", "add", "-q", "--detach", "../\(name)",
            ])
        }
        for tree in [repo, tree("a"), tree("b")] {
            let stale = tree.lastPathComponent != freshTree
            try writeBuild(in: tree, stale: stale)
        }
    }

    func tree(_ name: String) -> URL {
        root.appendingPathComponent(name)
    }

    func hasOutput(_ tree: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: tree.appendingPathComponent(".build").path
        )
    }

    func remove() { try? FileManager.default.removeItem(at: root) }

    var environment: [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["KIWIDESK_GATE_LOCK_HELD"] = nil
        env["KIWIDESK_GATE_PRUNE_BELOW_GB"] = nil
        env["KIWIDESK_GATE_DIR"] =
            root.appendingPathComponent("gate").path
        env["HOME"] = root.appendingPathComponent("home").path
        return env
    }

    func prune(from cwd: URL, apply: Bool = true) throws -> ScriptRun {
        try spawn(
            "/bin/bash",
            [script("prune-builds").path]
                + (apply ? ["--apply"] : []),
            environment: environment,
            currentDirectory: cwd
        )
    }

    /// `gate-lock echo gated` from the repo, with the disk
    /// threshold set above or below what the volume has free.
    func gateLock(
        lowDisk: Bool,
        nested: Bool = false
    ) throws -> ScriptRun {
        var env = environment
        env["KIWIDESK_GATE_PRUNE_BELOW_GB"] =
            lowDisk ? "1000000" : "0"
        if nested { env["KIWIDESK_GATE_LOCK_HELD"] = "1" }
        return try spawn(
            "/bin/bash",
            [script("gate-lock").path, "echo", "gated"],
            environment: env,
            currentDirectory: repo
        )
    }

    func hold(
        _ path: String,
        _ arguments: [String],
        in cwd: URL? = nil
    ) throws -> Holder {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        process.environment = environment
        if let cwd { process.currentDirectoryURL = cwd }
        let input = Pipe()
        process.standardInput = input
        process.standardOutput = FileHandle.nullDevice
        try process.run()
        return Holder(process: process, input: input)
    }

    /// Polls until `lockf -t 0` on the fixture lock refuses.
    func waitUntilGateHeld() throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            let probe = try spawn(
                "/usr/bin/lockf",
                ["-k", "-t", "0", lock.path, "/usr/bin/true"]
            )
            if probe.status == 75 { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        Issue.record("the holder never took the fixture gate")
    }

    private func script(_ name: String) -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/\(name)")
    }

    private func git(_ arguments: [String]) throws {
        let run = try spawn(
            "/usr/bin/git",
            arguments,
            environment: environment,
            currentDirectory: repo
        )
        #expect(run.status == 0, "git \(arguments): \(run.stderr)")
    }

    /// Swift Build's layout: markers at the top, `debug.yaml` one
    /// down. Dated after writing, so the folder dates stick too.
    private func writeBuild(in tree: URL, stale: Bool) throws {
        let build = tree.appendingPathComponent(".build")
        let out = build.appendingPathComponent("out")
        try FileManager.default.createDirectory(
            at: out,
            withIntermediateDirectories: true
        )
        let marker = build.appendingPathComponent("CACHEDIR.TAG")
        let yaml = out.appendingPathComponent("debug.yaml")
        for file in [marker, yaml] {
            try Data("x".utf8).write(to: file)
        }
        let date = Date().addingTimeInterval(stale ? -48 * 3600 : 0)
        for url in [yaml, out, marker, build] {
            try FileManager.default.setAttributes(
                [.modificationDate: date],
                ofItemAtPath: url.path
            )
        }
    }
}
