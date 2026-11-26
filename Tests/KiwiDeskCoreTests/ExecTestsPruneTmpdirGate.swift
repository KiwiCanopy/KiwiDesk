import Foundation
import Testing

/// `scripts/gate-lock` runs `scripts/prune-tmpdir` inside its lock
/// on the gated command's `$TMPDIR`, and the script's alarm ends a
/// stall, on `ExecTestsPruneTmpdir`'s fixture temp dir. Named into
/// the `ExecTests` partition: it holds real child processes.
@Suite("gate-lock prunes the temp dir inside its lock")
struct ExecTestsPruneTmpdirGate {
    /// The wiring: a gate run sweeps its command's `$TMPDIR`, and
    /// still runs the command.
    @Test("gate-lock prunes the command's temp dir and runs it")
    func gateLockPrunes() throws {
        let desk = try ExecTestsPruneTmpdir.makeDesk()
        defer { desk.remove() }
        let run = try gateLock(desk)
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout == "gated\n", "\(run.stdout)")
        #expect(!desk.exists("TemporaryDirectory.empty"))
        #expect(!desk.exists("TemporaryDirectory.leftovers"))
        #expect(desk.exists("TemporaryDirectory.otherFile"))
    }

    /// A prune moved ahead of gate-lock's own lockf would run while
    /// another gate step holds the slot.
    @Test("gate-lock never prunes before it holds the gate")
    func gateLockPrunesOnlyInsideTheLock() throws {
        let desk = try ExecTestsPruneTmpdir.makeDesk()
        defer { desk.remove() }
        let holder = Process()
        holder.executableURL = URL(fileURLWithPath: "/usr/bin/lockf")
        holder.arguments = ["-k", desk.lock.path, "/bin/cat"]
        let input = Pipe()
        holder.standardInput = input
        try holder.run()
        defer {
            try? input.fileHandleForWriting.close()
            holder.waitUntilExit()
        }
        let deadline = Date().addingTimeInterval(10)
        var held = false
        while !held, Date() < deadline {
            let probe = try spawn(
                "/usr/bin/lockf",
                ["-k", "-t", "0", desk.lock.path, "/usr/bin/true"]
            )
            held = probe.status == 75
            if !held { Thread.sleep(forTimeInterval: 0.05) }
        }
        #expect(held, "the holder never took the fixture gate")
        let run = try gateLock(desk, wait: "1")
        #expect(run.status == 75, "\(run.stdout)\(run.stderr)")
        #expect(desk.exists("TemporaryDirectory.empty"))
    }

    private func gateLock(
        _ desk: ExecTestsPruneTmpdir.Desk,
        wait: String? = nil
    ) throws -> ScriptRun {
        var env = desk.environment
        env["KIWIDESK_GATE_WAIT"] = wait
        // `spawn` pins the child's TMPDIR to the run's root; `env`
        // re-points it, so the gate's own default path runs.
        return try spawn(
            "/usr/bin/env",
            [
                "TMPDIR=\(desk.temp.path)/", "/bin/bash",
                desk.script("gate-lock"), "echo", "gated",
            ],
            environment: env,
            currentDirectory: desk.root
        )
    }

    /// `getconf` on PATH stalls and no `TMPDIR` is set, so the
    /// script hangs resolving its dir; the alarm must end it.
    @Test("the timeout alarm ends a stalled sweep")
    func timeoutEndsAStall() throws {
        let desk = try ExecTestsPruneTmpdir.makeDesk()
        defer { desk.remove() }
        let bin = desk.root.appendingPathComponent("bin")
        try FileManager.default.createDirectory(
            at: bin,
            withIntermediateDirectories: true
        )
        let pidFile = desk.root.appendingPathComponent("stall.pid")
        let stub = bin.appendingPathComponent("getconf")
        try """
        #!/bin/sh
        echo $$ > '\(pidFile.path)'
        exec sleep 600 > /dev/null 2>&1
        """.write(to: stub, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: stub.path
        )
        defer {
            if let pid = try? String(contentsOf: pidFile, encoding: .utf8)
                .trimmingCharacters(in: .whitespacesAndNewlines),
                let value = pid_t(pid)
            {
                kill(value, SIGKILL)
            }
        }
        let started = Date()
        let run = try spawn(
            "/usr/bin/env",
            [
                "-u", "TMPDIR", "PATH=\(bin.path):/usr/bin:/bin",
                desk.script("prune-tmpdir"), "--apply", "--timeout", "1",
            ]
        )
        #expect(Date().timeIntervalSince(started) < 30)
        #expect(run.status != 0, "\(run.stdout)\(run.stderr)")
        #expect(desk.exists("TemporaryDirectory.empty"))
    }
}
