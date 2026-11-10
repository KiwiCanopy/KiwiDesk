import Foundation
import Testing

/// `scripts/gate-lock`'s low-disk trigger and `prune-builds`'
/// timeout (#3186), on `PruneDesk`'s fixture worktrees.
@Suite("gate-lock prunes on low disk, inside its lock")
struct ExecTestsPruneBuildsTrigger {
    /// A trigger moved ahead of gate-lock's own lockf would prune
    /// while another gate step runs.
    @Test("gate-lock never prunes before it holds the gate")
    func gateLockPrunesOnlyInsideTheLock() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let holder = try desk.hold(
            "/usr/bin/lockf",
            ["-k", desk.lock.path, "/bin/cat"]
        )
        defer { holder.release() }
        try desk.waitUntilGateHeld()
        let run = try desk.gateLock(lowDisk: true, wait: "1")
        #expect(run.status == 75, "\(run.stdout)\(run.stderr)")
        #expect(desk.hasOutput(desk.tree("a")), "\(run.stderr)")
    }

    /// The sweep stalls in a stub `git`; a deadline that killed only
    /// the sweep's own shell would leave the stub running.
    @Test("the timeout stops the whole sweep, children included")
    func timeoutStopsTheSweep() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let run = try spawn(
            "/bin/bash",
            [desk.script("prune-builds").path, "--apply", "--timeout", "1"],
            environment: try desk.stalledEnvironment(),
            currentDirectory: desk.repo
        )
        #expect(run.status == 124, "\(run.stdout)\(run.stderr)")
        #expect(try desk.stallEnds(), "a child outlived the sweep")
    }

    /// The wrapper left the caller's process group, so a signal to
    /// it must reach the sweep, or a Ctrl-C frees the gate under it.
    @Test("a signal to the wrapper stops the whole sweep")
    func signalStopsTheSweep() throws {
        let desk = try PruneDesk()
        defer { desk.remove() }
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [
            desk.script("prune-builds").path, "--apply", "--timeout",
            "60",
        ]
        process.environment = try desk.stalledEnvironment()
        process.currentDirectoryURL = desk.repo
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        try process.run()
        try desk.waitUntilStalled()
        process.terminate()
        process.waitUntilExit()
        #expect(process.terminationStatus == 124)
        #expect(try desk.stallEnds(), "a child outlived the signal")
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

extension PruneDesk {
    var stallFile: URL { root.appendingPathComponent("stall") }

    /// `git` on PATH is a stub that records its pid and sleeps,
    /// its output detached so a survivor cannot hold a pipe open.
    func stalledEnvironment() throws -> [String: String] {
        try stubEnvironment(
            "git",
            """
            #!/bin/sh
            echo $$ > "\(stallFile.path)"
            exec /bin/sleep 30 < /dev/null > /dev/null 2>&1
            """
        )
    }

    /// The environment with `name` on PATH running `body`.
    func stubEnvironment(
        _ name: String,
        _ body: String
    ) throws -> [String: String] {
        let bin = root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(
            at: bin,
            withIntermediateDirectories: true
        )
        let stub = bin.appendingPathComponent(name)
        try body.write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stub.path
        )
        var env = environment
        env["PATH"] = bin.path + ":" + (env["PATH"] ?? "/usr/bin:/bin")
        return env
    }

    func waitUntilStalled() throws {
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            if stallPid() != nil { return }
            Thread.sleep(forTimeInterval: 0.05)
        }
        Issue.record("the sweep never reached the stub")
    }

    /// Whether the stub is gone within a few seconds; kills a
    /// survivor so it cannot outlive the test.
    func stallEnds() throws -> Bool {
        let pid = try #require(stallPid(), "the stub never ran")
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            if kill(pid, 0) != 0 { return true }
            Thread.sleep(forTimeInterval: 0.05)
        }
        kill(pid, SIGKILL)
        return false
    }

    func stallPid() -> pid_t? {
        guard
            let text = try? String(contentsOf: stallFile, encoding: .utf8)
        else { return nil }
        return pid_t(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
