import Foundation
import Testing

/// `scripts/check-homebrew-cask.py` and the read-only workflow that
/// runs it: a stale official cask reds, nothing writes the cask.
@Suite("Homebrew cask watch")
struct HomebrewCaskWatchTests {
    @Test("a cask at the release's version passes")
    func currentCaskPasses() throws {
        let run = try WatchFixture.check(
            cask: "4.2.1",
            now: "2026-11-20T00:00:00Z"
        )
        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(run.stdout.contains("at 4.2.1"))
    }

    @Test("a lag inside the grace passes")
    func lagInsideGracePasses() throws {
        let run = try WatchFixture.check(
            cask: "4.2.0",
            now: "2026-11-11T11:00:00Z"
        )
        #expect(run.status == 0, "stderr: \(run.stderr)")
        #expect(run.stdout.contains("inside the 24 h grace"))
    }

    @Test("a lag past the grace fails")
    func lagPastGraceFails() throws {
        let run = try WatchFixture.check(
            cask: "4.2.0",
            now: "2026-11-11T13:00:00Z"
        )
        #expect(run.status == 1)
        #expect(run.stdout.contains("::error::"))
        #expect(run.stdout.contains("4.2.0"))
    }

    @Test("a tag the cask cannot name is refused")
    func badTagRefused() throws {
        let run = try WatchFixture.check(
            cask: "4.2.1",
            now: "2026-11-20T00:00:00Z",
            tag: "v4.2.1-rc1"
        )
        #expect(run.status == 2)
        #expect(run.stderr.contains("vMAJOR.MINOR.PATCH"))
        let bare = try WatchFixture.check(
            cask: "4.2.1",
            now: "2026-11-20T00:00:00Z",
            tag: "4.2.1"
        )
        #expect(bare.status == 2)
    }

    @Test("a draft is never the release judged")
    func draftRefused() throws {
        let run = try WatchFixture.check(
            cask: "4.2.1",
            now: "2026-11-20T00:00:00Z",
            draft: true
        )
        #expect(run.status == 2)
        #expect(run.stderr.contains("not a published final release"))
    }

    @Test("a prerelease is never the release judged")
    func prereleaseRefused() throws {
        let run = try WatchFixture.check(
            cask: "4.2.1",
            now: "2026-11-20T00:00:00Z",
            prerelease: true
        )
        #expect(run.status == 2)
        #expect(run.stderr.contains("not a published final release"))
    }

    @Test("the workflow only reads, on a schedule")
    func workflowOnlyReads() throws {
        let yaml = try workflowSource("homebrew-watch.yml")
        #expect(yaml.contains("schedule:\n    - cron:"))
        #expect(yaml.contains("workflow_dispatch:"))
        #expect(yaml.contains("permissions:\n  contents: read"))
        // Bare words, so a quoted value, a job-level block, `write-all`
        // and `secrets[...]` / `toJSON(secrets)` all red. Trade: any
        // later use of either word, even harmless, reds too.
        #expect(!yaml.lowercased().contains("write"))
        #expect(!yaml.contains("secrets"))
        let read = try workflowStep(
            "Read the latest release and the cask",
            in: yaml
        )
        #expect(read.contains("releases/latest"))
        #expect(read.contains("formulae.brew.sh/api/cask/kiwidesk.json"))
        let check = try workflowStep("Fail when the cask lags", in: yaml)
        #expect(check.contains("scripts/check-homebrew-cask.py"))
        // A red must reach the run: nothing swallows the exit or
        // widens the script's own grace.
        for swallow in ["||", "continue-on-error", "--grace-hours"] {
            #expect(!check.contains(swallow), Comment(rawValue: swallow))
        }
    }
}

private enum WatchFixture {
    static let published = "2026-11-10T12:00:00Z"

    static var script: URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("check-homebrew-cask.py")
    }

    static func check(
        cask version: String,
        now: String,
        tag: String = "v4.2.1",
        draft: Bool = false,
        prerelease: Bool = false
    ) throws -> ScriptRun {
        let root =
            testTemporaryDirectory
            .appendingPathComponent("cask-watch-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: root) }
        let release = root.appendingPathComponent("release.json")
        let cask = root.appendingPathComponent("cask.json")
        let releaseJSON = """
            {"tag_name": "\(tag)", "draft": \(draft), \
            "prerelease": \(prerelease), \
            "published_at": "\(published)"}
            """
        try releaseJSON.write(
            to: release,
            atomically: true,
            encoding: .utf8
        )
        try "{\"token\": \"kiwidesk\", \"version\": \"\(version)\"}"
            .write(to: cask, atomically: true, encoding: .utf8)
        return try runPythonScript(
            at: script,
            arguments: [
                "--release", release.path, "--cask", cask.path,
                "--now", now,
            ]
        )
    }
}
