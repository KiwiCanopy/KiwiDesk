import Foundation
import Testing

/// `scripts/prune-tmpdir` removes only old `TemporaryDirectory.*`
/// folders holding nothing but the build tools' leftovers, and
/// `scripts/gate-lock` runs it on its own lock dir. Each case runs
/// the real scripts on a fixture temp dir of its own. Named into
/// the `ExecTests` partition: it holds real child processes.
@Suite("prune-tmpdir removes only old, empty build leftovers")
struct ExecTestsPruneTmpdir {
    private static let old = Date(timeIntervalSinceNow: -3 * 3600)

    /// Each fixture folder, and whether the prune may remove it.
    private static let cases: [(name: String, goes: Bool)] = [
        ("TemporaryDirectory.empty", true),
        ("TemporaryDirectory.leftovers", true),
        ("TemporaryDirectory.otherFile", false),
        ("TemporaryDirectory.subfolder", false),
        ("TemporaryDirectory.linkedKeep", false),
        ("TemporaryDirectory.fresh", false),
        ("TemporaryDirectory.freshFile", false),
        ("TemporaryDirectory.link", false),
        ("TemporaryDirectory.plainFile", false),
        ("NotTemporaryDirectory.empty", false),
        ("kiwi-run-1-abc", false),
    ]

    private struct Desk {
        let root =
            testTemporaryDirectory
            .appendingPathComponent("prune-tmp-\(UUID().uuidString)")
            .resolvingSymlinksInPath()
        var temp: URL { root.appendingPathComponent("temp") }
        var lock: URL {
            root.appendingPathComponent("gate/kiwidesk-gate.lock")
        }

        func url(_ name: String) -> URL {
            temp.appendingPathComponent(name)
        }

        func exists(_ name: String) -> Bool {
            (try? FileManager.default.attributesOfItem(
                atPath: url(name).path
            )) != nil
        }

        func remove() { try? FileManager.default.removeItem(at: root) }

        func script(_ name: String) -> String {
            scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/\(name)").path
        }

        var environment: [String: String] {
            var env = ProcessInfo.processInfo.environment
            env["KIWIDESK_GATE_LOCK_HELD"] = nil
            env["KIWIDESK_GATE_WAIT"] = nil
            env["KIWIDESK_GATE_PRUNE_BELOW_GB"] = "0"
            env["KIWIDESK_GATE_DIR"] =
                lock.deletingLastPathComponent().path
            return env
        }

        func prune(_ extra: [String] = ["--apply"]) throws -> ScriptRun {
            // By its shebang, as gate-lock runs it.
            try spawn(script("prune-tmpdir"), ["--dir", temp.path] + extra)
        }
    }

    private func makeDesk() throws -> Desk {
        let desk = Desk()
        let files = FileManager.default
        try files.createDirectory(
            at: desk.root.appendingPathComponent("outside"),
            withIntermediateDirectories: true
        )
        for dir in [desk.temp, desk.lock.deletingLastPathComponent()] {
            try files.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        func folder(_ name: String, _ children: [String] = []) throws {
            let dir = desk.url(name)
            try files.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
            for child in children {
                let path = dir.appendingPathComponent(child).path
                files.createFile(atPath: path, contents: Data("x".utf8))
            }
        }
        func age(_ path: String, to date: Date = Self.old) throws {
            try files.setAttributes(
                [.modificationDate: date],
                ofItemAtPath: path
            )
        }
        try folder("TemporaryDirectory.empty")
        try folder(
            "TemporaryDirectory.leftovers",
            [".keep-directory", "inputs-12.LinkFileList"]
        )
        try folder(
            "TemporaryDirectory.otherFile",
            [".keep-directory", "inputs-1.LinkFileList.bak"]
        )
        try folder("TemporaryDirectory.subfolder")
        try files.createDirectory(
            at: desk.url(
                "TemporaryDirectory.subfolder/inputs-1.LinkFileList"
            ),
            withIntermediateDirectories: false
        )
        try folder("TemporaryDirectory.linkedKeep")
        let target = desk.root.appendingPathComponent("outside/keep")
        files.createFile(atPath: target.path, contents: Data())
        try files.createSymbolicLink(
            at: desk.url("TemporaryDirectory.linkedKeep/.keep-directory"),
            withDestinationURL: target
        )
        try folder("TemporaryDirectory.fresh")
        try folder("TemporaryDirectory.freshFile", [".keep-directory"])
        // An old, empty folder: only the link keeps it.
        let linked = desk.root.appendingPathComponent("outside/empty")
        try files.createDirectory(
            at: linked,
            withIntermediateDirectories: false
        )
        // Holding a leftover: a followed link would delete it.
        let outsideKeep = linked.appendingPathComponent(".keep-directory")
        files.createFile(atPath: outsideKeep.path, contents: Data())
        try age(outsideKeep.path)
        try age(linked.path)
        try files.createSymbolicLink(
            at: desk.url("TemporaryDirectory.link"),
            withDestinationURL: linked
        )
        files.createFile(
            atPath: desk.url("TemporaryDirectory.plainFile").path,
            contents: Data()
        )
        try folder("NotTemporaryDirectory.empty")
        try folder("kiwi-run-1-abc")
        // Last, and the links themselves too (`-h`): writing a
        // folder's children moves its mtime, and FileManager dates
        // a link's target. Then the two fresh items alone.
        let format = DateFormatter()
        format.dateFormat = "yyyyMMddHHmm"
        let stamp = format.string(from: Self.old)
        let aged = try spawn(
            "/usr/bin/find",
            [
                desk.temp.path, "-mindepth", "1",
                "-exec", "touch", "-h", "-t", stamp, "{}", "+",
            ]
        )
        #expect(aged.status == 0, "\(aged.stderr)")
        let fresh = try spawn(
            "/usr/bin/touch",
            [
                desk.url("TemporaryDirectory.fresh").path,
                desk.url("TemporaryDirectory.freshFile/.keep-directory")
                    .path,
            ]
        )
        #expect(fresh.status == 0, "\(fresh.stderr)")
        return desk
    }

    @Test("each clause keeps its folder; only the leftovers go")
    func onlyOldEmptyLeftoversGo() throws {
        let desk = try makeDesk()
        defer { desk.remove() }
        let run = try desk.prune()
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("removed 2 "), "\(run.stdout)")
        for (name, goes) in Self.cases {
            #expect(desk.exists(name) != goes, "\(name)")
        }
        for outside in [
            "outside/keep", "outside/empty/.keep-directory",
        ] {
            #expect(
                FileManager.default.fileExists(
                    atPath: desk.root.appendingPathComponent(outside).path
                ),
                "\(outside)"
            )
        }
    }

    @Test("a dry run removes nothing")
    func dryRunRemovesNothing() throws {
        let desk = try makeDesk()
        defer { desk.remove() }
        let run = try desk.prune([])
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("would remove 2 "), "\(run.stdout)")
        for (name, _) in Self.cases {
            #expect(desk.exists(name), "\(name)")
        }
    }

    @Test("a longer age guard keeps every folder")
    func longerAgeKeepsAll() throws {
        let desk = try makeDesk()
        defer { desk.remove() }
        let run = try desk.prune(["--apply", "--age-minutes", "600"])
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("removed 0 "), "\(run.stdout)")
        #expect(desk.exists("TemporaryDirectory.empty"))
    }

    /// The wiring: a gate run sweeps its lock dir, and still runs
    /// its command.
    @Test("gate-lock prunes its own lock dir and runs the command")
    func gateLockPrunes() throws {
        let desk = try makeDesk()
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
        let desk = try makeDesk()
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
        _ desk: Desk,
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
        let desk = try makeDesk()
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
