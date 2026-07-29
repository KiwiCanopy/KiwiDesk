import Foundation
import Testing

/// `scripts/bump-version.sh` really spawned (#32).
///
/// The tag ↔ `KiwiDeskVersion.semantic` mirror cannot be tested
/// here — at `swift test` time the tag does not exist yet, and
/// the only moment both halves exist is inside the release
/// workflow, which is where that guard lives.
///
/// What *is* testable locally is the mechanism underneath it, and
/// it is worth testing because the whole release pipeline trusts
/// it: `sed -i ''` exits 0 when it matches nothing, so a
/// declaration that drifts away from `let <name> = "<value>"`
/// turns the stamp into a silent no-op. The workflow would then
/// build a binary carrying the previous version and Apple-notarize
/// it under the new one — and no step before the download says so.
///
/// So the fixture copies the **real**
/// `Sources/KiwiDeskCore/App/KiwiDeskVersion.swift` rather than a
/// hand-written stand-in. That is the entire point: a test over
/// invented file contents would keep passing on the day someone
/// adds a type annotation to the shipped declaration, which is
/// exactly the change this exists to catch.
///
/// Bash, not `ScriptFixture`'s `runPythonScript` — that harness is
/// python-only, and per `.claude/rules/tests.md` a first copy stays
/// a per-file private helper.
@Suite("Version stamping script")
struct ScriptStampTests {
    // MARK: - The real declaration shape

    @Test("stamps the version and leaves the commit unknown")
    func stampsVersionOnly() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        let run = try fixture.bump(["1.2.3"])

        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(try fixture.declaration("semantic") == "1.2.3")
        // Not merely "not the old value": a checked-in tree cannot
        // know the commit it becomes, so "unknown" is the only
        // honest content and the script must reset it.
        #expect(try fixture.declaration("commit") == "unknown")
    }

    @Test("--stamp-commit writes the real HEAD")
    func stampCommitWritesHead() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        let run = try fixture.bump(["1.2.3", "--stamp-commit"])

        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(try fixture.declaration("semantic") == "1.2.3")
        let stamped = try fixture.declaration("commit")
        #expect(stamped == fixture.headSHA)
        // Guards the assertion above against passing vacuously if
        // the fixture's git setup ever stops producing a SHA.
        #expect(stamped != "unknown")
        #expect(!(stamped ?? "").isEmpty)
    }

    @Test("re-stamping resets a previously stamped commit")
    func reStampResetsCommit() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        #expect(
            try fixture.bump(["1.2.3", "--stamp-commit"])
                .status == 0
        )
        #expect(try fixture.declaration("commit") != "unknown")

        // A plain bump after a stamped one must not leave the old
        // SHA behind: the tree would then claim a commit it is not.
        #expect(try fixture.bump(["1.2.4"]).status == 0)
        #expect(try fixture.declaration("commit") == "unknown")
    }

    // MARK: - The guard that makes the above trustworthy

    @Test("a drifted declaration fails instead of no-op passing")
    func driftedDeclarationFails() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        // The realistic drift: a type annotation. Equally, wrapping
        // the line for the 79-column limit, or making it computed.
        try fixture.rewriteVersionFile { source in
            source.replacingOccurrences(
                of: "let semantic = ",
                with: "let semantic: String = "
            )
        }

        let run = try fixture.bump(["9.9.9"])

        // `Comment` is ExpressibleByStringLiteral, so the message
        // stays ONE literal — a `+`-concatenation does not convert.
        #expect(
            run.status != 0,
            "an unmatchable declaration must fail, not no-op pass"
        )
        #expect(run.stderr.contains("semantic"))
    }

    // MARK: - What may be released at all

    @Test("a prerelease suffix is refused before anything is cut")
    func prereleaseRefused() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        // CFBundleVersion takes 1-3 integers, so build-app.sh
        // rejects this — but only after `scripts/release.sh` has
        // already PUSHED the tag, and a fetched tag cannot be
        // taken back. The narrower gate has to run first.
        let run = try fixture.bump(["0.9.0-rc1"])

        #expect(run.status != 0)
        #expect(try fixture.declaration("semantic") == original)
    }

    @Test("a two-part version is refused")
    func twoPartRefused() throws {
        let fixture = try StampFixture()
        defer { fixture.cleanup() }

        #expect(try fixture.bump(["0.9"]).status != 0)
        #expect(try fixture.declaration("semantic") == original)
    }

    /// The shipped version, read once so the rejection tests can
    /// assert the file was left alone without hard-coding a number
    /// that a real bump would falsify.
    private var original: String? {
        guard
            let source = try? String(
                contentsOf: StampFixture.realVersionFile,
                encoding: .utf8
            )
        else { return nil }
        return StampFixture.declaration("semantic", in: source)
    }
}

// MARK: - Fixture

/// A throwaway repo-shaped tree holding a copy of the real script
/// and the real version file. `bump-version.sh` derives its root
/// from `$0`, and `--stamp-commit` shells out to git, so the tree
/// has to be both correctly shaped and a real repository.
private struct StampFixture {
    let root: URL
    let headSHA: String?

    static var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    static var realVersionFile: URL {
        repoRoot
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("App")
            .appendingPathComponent("KiwiDeskVersion.swift")
    }

    var versionFile: URL {
        root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("App")
            .appendingPathComponent("KiwiDeskVersion.swift")
    }

    init() throws {
        let fm = FileManager.default
        // Local URLs, not the computed properties: Swift forbids
        // touching an instance member before every stored property
        // is initialized, and `headSHA` is filled at the bottom.
        let root = fm.temporaryDirectory
            .appendingPathComponent("stamp-\(UUID().uuidString)")
        self.root = root
        let appDir =
            root
            .appendingPathComponent("Sources")
            .appendingPathComponent("KiwiDeskCore")
            .appendingPathComponent("App")
        let scriptsDir = root.appendingPathComponent("scripts")
        for dir in [appDir, scriptsDir] {
            try fm.createDirectory(
                at: dir,
                withIntermediateDirectories: true
            )
        }
        // Copied, never written from a literal — see the suite
        // docstring.
        try fm.copyItem(
            at: Self.realVersionFile,
            to:
                appDir
                .appendingPathComponent("KiwiDeskVersion.swift")
        )
        try fm.copyItem(
            at: Self.repoRoot
                .appendingPathComponent("scripts")
                .appendingPathComponent("bump-version.sh"),
            to:
                scriptsDir
                .appendingPathComponent("bump-version.sh")
        )
        // `--stamp-commit` asks git for HEAD, so the fixture needs
        // one. `-c` flags rather than `git config`, so the run
        // cannot depend on the developer's global identity.
        let git = ["init", "--quiet", "--initial-branch=main"]
        _ = try Self.run("/usr/bin/git", git, in: root)
        _ = try Self.run("/usr/bin/git", ["add", "-A"], in: root)
        _ = try Self.run(
            "/usr/bin/git",
            [
                "-c", "user.name=t", "-c", "user.email=t@t",
                "commit", "--quiet", "-m", "fixture",
            ],
            in: root
        )
        headSHA = try Self.run(
            "/usr/bin/git",
            ["rev-parse", "--short", "HEAD"],
            in: root
        ).stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    @discardableResult
    func bump(_ arguments: [String]) throws -> ScriptRun {
        try Self.run(
            "/bin/bash",
            [
                root.appendingPathComponent("scripts")
                    .appendingPathComponent("bump-version.sh").path
            ] + arguments,
            in: root
        )
    }

    func rewriteVersionFile(
        _ transform: (String) -> String
    ) throws {
        let source = try String(
            contentsOf: versionFile,
            encoding: .utf8
        )
        try transform(source).write(
            to: versionFile,
            atomically: true,
            encoding: .utf8
        )
    }

    func declaration(_ name: String) throws -> String? {
        Self.declaration(
            name,
            in: try String(contentsOf: versionFile, encoding: .utf8)
        )
    }

    /// The same shape `build-app.sh` and the release workflow
    /// parse, so this reads the file the way the pipeline does
    /// rather than however is convenient here.
    static func declaration(
        _ name: String,
        in source: String
    ) -> String? {
        for line in source.split(separator: "\n") {
            guard
                let range = line.range(of: "let \(name) = \"")
            else { continue }
            let rest = line[range.upperBound...]
            guard let end = rest.firstIndex(of: "\"") else {
                continue
            }
            return String(rest[..<end])
        }
        return nil
    }

    /// Drains both pipes before waiting — a child that fills a
    /// pipe buffer while the test blocks on exit deadlocks.
    static func run(
        _ launchPath: String,
        _ arguments: [String],
        in directory: URL
    ) throws -> ScriptRun {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: launchPath)
        process.arguments = arguments
        process.currentDirectoryURL = directory
        let out = Pipe()
        let err = Pipe()
        process.standardOutput = out
        process.standardError = err
        try process.run()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return ScriptRun(
            status: process.terminationStatus,
            stdout: String(data: outData, encoding: .utf8) ?? "",
            stderr: String(data: errData, encoding: .utf8) ?? ""
        )
    }
}
