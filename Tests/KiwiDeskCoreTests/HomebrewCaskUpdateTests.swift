import Foundation
import Testing

@Suite("Homebrew cask updater")
struct HomebrewCaskUpdateTests {
    @Test("updates only the version and digest")
    func updatesVersionAndDigest() throws {
        let fixture = try CaskFixture()
        defer { fixture.cleanup() }
        let digest = String(repeating: "b", count: 64)

        let run = try fixture.update("1.2.3", digest)

        #expect(run.status == 0, "stderr: \(run.stderr)")
        let source = try fixture.source()
        #expect(source.contains("  version \"1.2.3\""))
        #expect(source.contains("  sha256 \"\(digest)\""))
        #expect(source.contains("releases/download/v#{version}"))
        #expect(source.contains("app \"KiwiDesk.app\""))
    }

    @Test("same release is an idempotent no-op")
    func sameReleaseNoOp() throws {
        let fixture = try CaskFixture()
        defer { fixture.cleanup() }
        let digest = String(repeating: "c", count: 64)
        #expect(try fixture.update("1.2.3", digest).status == 0)
        let once = try fixture.source()

        let twice = try fixture.update("1.2.3", digest)

        #expect(twice.status == 0, "stderr: \(twice.stderr)")
        #expect(twice.stdout.contains("already at 1.2.3"))
        #expect(try fixture.source() == once)
    }

    @Test("malformed inputs fail without changing the cask")
    func malformedInputsFailClosed() throws {
        let fixture = try CaskFixture()
        defer { fixture.cleanup() }
        let original = try fixture.source()

        let version = try fixture.update(
            "1.2.3-rc1",
            String(repeating: "d", count: 64)
        )
        #expect(version.status != 0)
        #expect(try fixture.source() == original)

        let digest = try fixture.update("1.2.3", "not-a-digest")
        #expect(digest.status != 0)
        #expect(try fixture.source() == original)
    }

    @Test("an older release cannot roll the tap back")
    func olderReleaseFailsClosed() throws {
        let fixture = try CaskFixture()
        defer { fixture.cleanup() }
        let original = try fixture.source()

        let run = try fixture.update(
            "0.8.9",
            String(repeating: "f", count: 64)
        )

        #expect(run.status != 0)
        #expect(run.stderr.contains("refusing to downgrade"))
        #expect(try fixture.source() == original)
    }

    @Test("a drifted cask fails instead of partially updating")
    func driftedCaskFailsClosed() throws {
        let fixture = try CaskFixture()
        defer { fixture.cleanup() }
        try fixture.rewrite { source in
            source.replacingOccurrences(
                of: "  sha256 \"",
                with: "  sha256 :no_check # \""
            )
        }
        let original = try fixture.source()

        let run = try fixture.update(
            "1.2.3",
            String(repeating: "e", count: 64)
        )

        #expect(run.status != 0)
        #expect(run.stderr.contains("sha256"))
        #expect(try fixture.source() == original)
    }

    @Test("workflow advances only published verified releases")
    func workflowGuardsDistributionBoundary() throws {
        let workflow = try String(
            contentsOf: CaskFixture.repoRoot
                .appendingPathComponent(".github")
                .appendingPathComponent("workflows")
                .appendingPathComponent("homebrew.yml"),
            encoding: .utf8
        )

        #expect(workflow.contains("types: [published]"))
        #expect(workflow.contains("workflow_dispatch:"))
        #expect(workflow.contains("queue: max"))
        #expect(workflow.contains("cancel-in-progress: false"))
        #expect(workflow.contains("HOMEBREW_TAP_DEPLOY_KEY"))
        #expect(workflow.contains("assets | length"))
        #expect(workflow.contains("sha256sum"))
        #expect(workflow.contains("update-homebrew-cask.py"))
    }
}

private struct CaskFixture {
    let root: URL
    let cask: URL

    static var repoRoot: URL { scriptFixtureRepoRoot() }

    static var updater: URL {
        repoRoot
            .appendingPathComponent("scripts")
            .appendingPathComponent("update-homebrew-cask.py")
    }

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("cask-\(UUID().uuidString)")
        cask = root.appendingPathComponent("kiwidesk.rb")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        try Self.initial.write(
            to: cask,
            atomically: true,
            encoding: .utf8
        )
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func source() throws -> String {
        try String(contentsOf: cask, encoding: .utf8)
    }

    func update(_ version: String, _ digest: String) throws -> ScriptRun {
        try runPythonScript(
            at: Self.updater,
            arguments: [version, digest, "--cask", cask.path]
        )
    }

    func rewrite(_ transform: (String) -> String) throws {
        let before = try source()
        let after = transform(before)
        #expect(after != before, "fixture rewrite matched nothing")
        try after.write(to: cask, atomically: true, encoding: .utf8)
    }

    private static var initial: String {
        let digest = String(repeating: "a", count: 64)
        let url =
            "https://github.com/KiwiCanopy/KiwiDesk/releases/"
            + "download/v#{version}/KiwiDesk-#{version}.zip"
        return """
            cask "kiwidesk" do
              version "0.9.0"
              sha256 "\(digest)"

              url "\(url)"
              name "KiwiDesk"
              desc "Tiling window manager with layouts, profiles, and Lua"
              homepage "https://kiwidesk.kiwicanopy.com/"

              app "KiwiDesk.app"
            end
            """
    }
}
