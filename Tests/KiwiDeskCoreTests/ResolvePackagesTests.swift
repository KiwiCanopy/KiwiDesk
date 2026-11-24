import Foundation
import Testing

/// `scripts/resolve-packages` (#3591): a transient github.com
/// refusal while cloning a dependency retries once, and a stale
/// or broken `Package.resolved` still fails. The script runs
/// against a fake `swift` that records each call and fails the
/// first `failures` of them, in a scratch tree standing in for
/// both the package root and `$HOME`.
@Suite("Package resolve retries once (#3591)")
struct ResolvePackagesTests {
    private static let script = scriptFixtureRepoRoot()
        .appendingPathComponent("scripts/resolve-packages")

    private static let cache =
        "Library/Caches/org.swift.swiftpm/repositories"

    private struct Run {
        let status: Int32
        let calls: [String]
        let stderr: String
        let stdout: String
        let root: URL
    }

    /// Runs the script with a fake swift that fails its first
    /// `failures` calls, exiting with their 1-based count, and
    /// exits 0 after. Each call logs its arguments and which
    /// clone folders still exist: the package's, then the user's.
    private func resolve(
        failures: Int,
        onCI: Bool = true
    ) throws -> Run {
        let root =
            testTemporaryDirectory
            .appendingPathComponent("resolve-\(UUID())")
        let files = FileManager.default
        for dir in [".build/repositories", Self.cache] {
            try files.createDirectory(
                at: root.appendingPathComponent(dir),
                withIntermediateDirectories: true
            )
        }
        let fake = root.appendingPathComponent("fake-swift")
        let body = """
            #!/bin/bash
            n=$(wc -l < calls.log 2>/dev/null || echo 0)
            own=gone; user=gone
            [ -d .build/repositories ] && own=kept
            [ -d "$HOME/\(Self.cache)" ] && user=kept
            echo "$* $own $user" >> calls.log
            [ "$n" -lt \(failures) ] && exit $((n + 1))
            exit 0
            """
        try body.write(to: fake, atomically: true, encoding: .utf8)
        try files.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: fake.path
        )
        var env = ProcessInfo.processInfo.environment
        env["HOME"] = root.path
        env["KIWIDESK_RESOLVE_SWIFT"] = fake.path
        env["CI"] = onCI ? "true" : nil
        let run = try spawn(
            "/bin/bash",
            [Self.script.path],
            environment: env,
            currentDirectory: root
        )
        let log =
            (try? String(
                contentsOf: root.appendingPathComponent("calls.log"),
                encoding: .utf8
            )) ?? ""
        return Run(
            status: run.status,
            calls: log.split(separator: "\n").map(String.init),
            stderr: run.stderr,
            stdout: run.stdout,
            root: root
        )
    }

    private static let strict =
        "package resolve --only-use-versions-from-resolved-file"

    @Test("A first success resolves once and clears nothing")
    func successRunsOnce() throws {
        let run = try resolve(failures: 0)
        #expect(run.status == 0)
        #expect(run.calls == ["\(Self.strict) kept kept"])
        #expect(!run.stdout.contains("::warning::"))
    }

    @Test("A first failure clears both clone folders and retries")
    func failureRetriesOnce() throws {
        let run = try resolve(failures: 1)
        #expect(run.status == 0)
        #expect(
            run.calls == [
                "\(Self.strict) kept kept", "\(Self.strict) gone gone",
            ]
        )
        #expect(run.stdout.contains("retrying once"))
        let files = FileManager.default
        for dir in [".build/repositories", Self.cache] {
            #expect(
                !files.fileExists(
                    atPath: run.root.appendingPathComponent(dir).path
                ),
                "\(dir) survived the retry"
            )
        }
    }

    @Test("A second failure fails the step, with no third try")
    func secondFailureFails() throws {
        let run = try resolve(failures: 5)
        // The second attempt's own status, not a fixed code.
        #expect(run.status == 2)
        #expect(run.calls.count == 2)
        #expect(run.stderr.contains("failed twice"))
    }

    /// Off CI the user-global clone cache is a developer's, so
    /// only the package's own clones are cleared.
    @Test("Off CI the retry keeps the user's clone cache")
    func offCiKeepsUserCache() throws {
        let run = try resolve(failures: 1, onCI: false)
        #expect(run.status == 0)
        #expect(
            run.calls == [
                "\(Self.strict) kept kept", "\(Self.strict) gone kept",
            ]
        )
    }
}
