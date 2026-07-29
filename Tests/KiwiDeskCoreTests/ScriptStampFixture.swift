import Foundation
import Testing

/// The fixture behind `ScriptStampTests`, split out only
/// because the two together cross the 350-line hard ceiling
/// (`.claude/rules/tests.md`: split before you reach it).
///
/// **Not a shared harness, and not a sixth ratified
/// exception.** It is internal rather than private purely
/// because Swift scopes `private` to the file, and it has
/// exactly one consumer. A second suite wanting it is the
/// moment to weigh it against that rule's two admission
/// grounds, not before.
struct StampFixture {
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

    /// Applies `transform` and **asserts it changed something**.
    ///
    /// A `replacingOccurrences` whose needle is absent is a silent
    /// no-op, so a caller introducing drift would go on to assert
    /// against a rewrite it never performed — green for the wrong
    /// reason, and green precisely when the shipped declaration has
    /// already drifted. The canary has to guard the thing the test
    /// consumes, so it lives here rather than at one call site.
    func rewriteVersionFile(
        _ transform: (String) -> String
    ) throws {
        let source = try String(
            contentsOf: versionFile,
            encoding: .utf8
        )
        let rewritten = transform(source)
        #expect(
            rewritten != source,
            "the transform matched nothing — it rewrote no drift"
        )
        try rewritten.write(
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

    /// Reads both pipes before waiting, so a child whose stdout
    /// outgrows the pipe buffer cannot block on write while this
    /// blocks on exit.
    ///
    /// The reads are **sequential**, so this is not a general
    /// guarantee: a child that filled its *stderr* buffer before
    /// closing stdout would still deadlock. Sound for `git` and
    /// `bump-version.sh` (a few lines of stderr at most). Stated
    /// with the same caveat as `ScriptFixture.runPythonScript` on
    /// purpose — `.claude/rules/tests.md` names "an undrained
    /// pipe, a missed `stderr`" as the drift that silently changes
    /// what a suite observes, so the two copies must not disagree
    /// about what they promise.
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
