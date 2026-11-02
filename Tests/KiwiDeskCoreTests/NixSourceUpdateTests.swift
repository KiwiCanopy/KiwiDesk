import Foundation
import Testing

/// The KiwiCanopy/nix pin updater and its workflow (#2909), the
/// Nix twin of `HomebrewCaskUpdateTests`.
@Suite("Nix source updater")
struct NixSourceUpdateTests {
    /// 4.1.0's published ZIP: its GitHub digest and the SRI hash the
    /// flake pinned by hand, so the conversion is held to Nix's.
    private static let digest =
        "58bca3f223c0d22d35409e1c37f6883e41a8cf891eaf072f34e0d0aec925aa52"
    private static let sri =
        "sha256-WLyj8iPA0i01QJ4cN/aIPkGoz4kerwcvNODQrsklqlI="

    @Test("a newer release rewrites version, url and hash")
    func updatesThePin() throws {
        let fixture = try SourceFixture(version: "4.0.0")
        defer { fixture.cleanup() }

        let run = try fixture.update("4.1.0", Self.digest)

        #expect(run.status == 0, "stderr: \(run.stderr)")
        let pin = try fixture.pin()
        #expect(pin["version"] == "4.1.0")
        #expect(pin["hash"] == Self.sri)
        #expect(
            pin["url"]
                == "https://github.com/KiwiCanopy/KiwiDesk/releases/"
                + "download/v4.1.0/KiwiDesk-4.1.0.zip"
        )
    }

    @Test("same release is an idempotent no-op")
    func sameReleaseNoOp() throws {
        let fixture = try SourceFixture(version: "4.0.0")
        defer { fixture.cleanup() }
        #expect(try fixture.update("4.1.0", Self.digest).status == 0)
        let once = try fixture.source()

        let twice = try fixture.update("4.1.0", Self.digest)

        #expect(twice.status == 0, "stderr: \(twice.stderr)")
        #expect(twice.stdout.contains("already at 4.1.0"))
        #expect(try fixture.source() == once)
    }

    @Test("same version with different bytes fails closed")
    func sameVersionDifferentHashFailsClosed() throws {
        let fixture = try SourceFixture(version: "4.0.0")
        defer { fixture.cleanup() }
        let original = try fixture.source()

        let run = try fixture.update(
            "4.0.0",
            String(repeating: "b", count: 64)
        )

        #expect(run.status != 0)
        #expect(run.stderr.contains("refusing to replace hash"))
        #expect(try fixture.source() == original)
    }

    @Test("an older release cannot roll the flake back")
    func olderReleaseFailsClosed() throws {
        let fixture = try SourceFixture(version: "4.0.0")
        defer { fixture.cleanup() }
        let original = try fixture.source()

        let run = try fixture.update("3.9.9", Self.digest)

        #expect(run.status != 0)
        #expect(run.stderr.contains("refusing to downgrade"))
        #expect(try fixture.source() == original)
    }

    @Test("malformed inputs fail without changing the pin")
    func malformedInputsFailClosed() throws {
        let fixture = try SourceFixture(version: "4.0.0")
        defer { fixture.cleanup() }
        let original = try fixture.source()

        #expect(try fixture.update("4.1.0-rc1", Self.digest).status != 0)
        #expect(try fixture.update("4.1.0", "not-a-digest").status != 0)
        #expect(try fixture.source() == original)
    }

    /// A pin that grew or lost a key is a shape the updater does not
    /// own, so it refuses rather than rewriting the file.
    @Test("a drifted pin fails instead of being rewritten")
    func driftedPinFailsClosed() throws {
        let fixture = try SourceFixture(version: "4.0.0", extra: true)
        defer { fixture.cleanup() }
        let original = try fixture.source()

        let run = try fixture.update("4.1.0", Self.digest)

        #expect(run.status != 0)
        #expect(run.stderr.contains("expected exactly the keys"))
        #expect(try fixture.source() == original)
    }

    @Test("workflow advances only published verified releases")
    func workflowGuardsDistributionBoundary() throws {
        let workflow = try String(
            contentsOf: SourceFixture.repoRoot
                .appendingPathComponent(".github")
                .appendingPathComponent("workflows")
                .appendingPathComponent("nix.yml"),
            encoding: .utf8
        )

        #expect(workflow.contains("types: [published]"))
        #expect(workflow.contains("workflow_dispatch:"))
        #expect(workflow.contains("queue: max"))
        #expect(workflow.contains("cancel-in-progress: false"))
        #expect(workflow.contains("secrets.NIX_REPO_DEPLOY_KEY"))
        #expect(workflow.contains("repository: KiwiCanopy/nix"))
        #expect(
            workflow.contains("select(.name == $want)"),
            "the archive must be picked by name"
        )
        #expect(!workflow.contains("jq -r '.assets[0]"))
        #expect(workflow.contains("sha256sum"))
        #expect(workflow.contains("scripts/update-nix-source.py"))
        #expect(!workflow.contains("HOMEBREW_TAP_DEPLOY_KEY"))
    }

    /// The two channels verify a release the same way: a check
    /// tightened in one workflow and not the other leaves a channel
    /// shipping bytes the other would refuse.
    @Test("both workflows verify the release identically")
    func verificationMatchesHomebrew() throws {
        let nix = try Self.verification(in: "nix.yml")
        let brew = try Self.verification(in: "homebrew.yml")
        #expect(nix.count > 20, "verification steps not found")
        #expect(nix == brew)
    }

    /// The steps from the release check to the deploy-key check,
    /// without comment lines, which may differ.
    private static func verification(in name: String) throws -> [String] {
        let source = try String(
            contentsOf: SourceFixture.repoRoot
                .appendingPathComponent(".github/workflows/\(name)"),
            encoding: .utf8
        )
        guard
            let start = source.range(
                of: "- name: Verify the published release asset"
            ),
            let end = source.range(
                of: "- name: Require the",
                range: start.upperBound..<source.endIndex
            )
        else { return [] }
        return source[start.lowerBound..<end.lowerBound]
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") }
    }
}

private struct SourceFixture {
    let root: URL
    let file: URL

    static var repoRoot: URL { scriptFixtureRepoRoot() }

    static var updater: URL {
        repoRoot
            .appendingPathComponent("scripts")
            .appendingPathComponent("update-nix-source.py")
    }

    init(version: String, extra: Bool = false) throws {
        root =
            testTemporaryDirectory
            .appendingPathComponent("nix-\(UUID().uuidString)")
        file = root.appendingPathComponent("source.json")
        try FileManager.default.createDirectory(
            at: root,
            withIntermediateDirectories: true
        )
        let url =
            "https://github.com/KiwiCanopy/KiwiDesk/releases/download/"
            + "v\(version)/KiwiDesk-\(version).zip"
        let hash = "sha256-" + String(repeating: "A", count: 43) + "="
        let drift = extra ? ",\n  \"rev\": \"main\"" : ""
        let json = """
            {
              "version": "\(version)",
              "url": "\(url)",
              "hash": "\(hash)"\(drift)
            }

            """
        try json.write(to: file, atomically: true, encoding: .utf8)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }

    func source() throws -> String {
        try String(contentsOf: file, encoding: .utf8)
    }

    func pin() throws -> [String: String] {
        let data = try Data(contentsOf: file)
        return try JSONDecoder().decode([String: String].self, from: data)
    }

    func update(_ version: String, _ digest: String) throws -> ScriptRun {
        try runPythonScript(
            at: Self.updater,
            arguments: [version, digest, "--source", file.path]
        )
    }
}
