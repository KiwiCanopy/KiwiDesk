import Foundation
import Testing

/// `scripts/prune-tmpdir` removes only old `TemporaryDirectory.*`
/// folders holding nothing but the build tools' leftovers. Each case runs
/// the real scripts on a fixture temp dir of its own. Named into
/// the `ExecTests` partition: it holds real child processes.
/// `ExecTestsPruneTmpdirGate` holds the gate-lock wiring and the
/// timeout.
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

    struct Desk {
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

    static func makeDesk() throws -> Desk {
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
        let desk = try Self.makeDesk()
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
        let desk = try Self.makeDesk()
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
        let desk = try Self.makeDesk()
        defer { desk.remove() }
        let run = try desk.prune(["--apply", "--age-minutes", "600"])
        #expect(run.status == 0, "\(run.stderr)")
        #expect(run.stdout.contains("removed 0 "), "\(run.stdout)")
        #expect(desk.exists("TemporaryDirectory.empty"))
    }
}
