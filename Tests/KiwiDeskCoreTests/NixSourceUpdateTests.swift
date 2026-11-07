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
        expectEqual(pin["version"], "4.1.0")
        expectEqual(pin["hash"], Self.sri)
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

        let version = try fixture.update("4.1.0-rc1", Self.digest)
        #expect(version.status != 0)
        #expect(version.stderr.contains("MAJOR.MINOR.PATCH"))
        let digest = try fixture.update("4.1.0", "not-a-digest")
        #expect(digest.status != 0)
        #expect(digest.stderr.contains("64 lowercase hex"))
        #expect(try fixture.source() == original)
    }

    @Test("a pin with an invalid version or hash is refused")
    func invalidPinFailsClosed() throws {
        for (field, bad, message) in [
            ("version", "4.0", "pinned version is invalid"),
            ("hash", "sha256-short", "pinned hash is invalid"),
        ] {
            let fixture = try SourceFixture(version: "4.0.0")
            defer { fixture.cleanup() }
            try fixture.set(field, to: bad)
            let original = try fixture.source()

            let run = try fixture.update("4.1.0", Self.digest)

            #expect(run.status != 0, Comment(rawValue: field))
            #expect(run.stderr.contains(message), Comment(rawValue: field))
            #expect(try fixture.source() == original)
        }
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
        let yaml = try workflowSource("nix.yml")
        for needle in [
            "types: [published]", "workflow_dispatch:", "queue: max",
            "cancel-in-progress: false",
        ] {
            #expect(yaml.contains(needle), Comment(rawValue: needle))
        }
        #expect(!yaml.contains("HOMEBREW_TAP_DEPLOY_KEY"))

        let pick = try workflowStep(
            "Verify the published release asset",
            in: yaml
        )
        #expect(pick.contains("select(.name == $want)"))
        #expect(!pick.contains(".assets[0]"))
        let bytes = try workflowStep(
            "Download and verify the archive bytes",
            in: yaml
        )
        #expect(bytes.contains("sha256sum"))
        let checkout = try workflowStep(
            "Check out KiwiCanopy/nix",
            in: yaml
        )
        #expect(checkout.contains("repository: KiwiCanopy/nix"))
        #expect(
            checkout.contains("ssh-key: ${{ secrets.NIX_REPO_DEPLOY_KEY }}")
        )
        let update = try workflowStep(
            "Update and validate the source pin",
            in: yaml
        )
        #expect(update.contains("scripts/update-nix-source.py"))
        let push = try workflowStep(
            "Commit and push the source pin",
            in: yaml
        )
        #expect(push.contains("git -C kiwicanopy-nix push origin HEAD:main"))
    }

    /// The two channels verify a release the same way: a check
    /// tightened in one workflow and not the other leaves a channel
    /// shipping bytes the other would refuse. Compared: the trigger,
    /// the tag, the permissions, the updater checkout and both
    /// verification steps. Not compared, since they must differ: the
    /// concurrency group, the target repository and its deploy key.
    @Test("both workflows verify the release identically")
    func verificationMatchesHomebrew() throws {
        let nix = try workflowSource("nix.yml")
        let brew = try workflowSource("homebrew.yml")
        for step in [
            "Verify the published release asset",
            "Download and verify the archive bytes",
        ] {
            #expect(
                try Self.lines(of: step, in: nix)
                    == Self.lines(of: step, in: brew),
                Comment(rawValue: step)
            )
        }
        for shared in [
            "types: [published]",
            "TAG: ${{ github.event.release.tag_name || inputs.tag }}",
            "contents: read",
            "ref: ${{ github.event.repository.default_branch }}",
        ] {
            #expect(nix.contains(shared), Comment(rawValue: shared))
            #expect(brew.contains(shared), Comment(rawValue: shared))
        }
    }

    /// A step's non-blank lines: stripping a comment block leaves
    /// blank lines whose count differs between the twins.
    private static func lines(
        of step: String,
        in yaml: String
    ) throws -> [Substring] {
        try workflowStep(step, in: yaml)
            .split(separator: "\n")
            .filter { !$0.allSatisfy(\.isWhitespace) }
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

    func set(_ field: String, to value: String) throws {
        var pin = try pin()
        pin[field] = value
        let data = try JSONEncoder().encode(pin)
        try data.write(to: file)
    }

    func update(_ version: String, _ digest: String) throws -> ScriptRun {
        try runPythonScript(
            at: Self.updater,
            arguments: [version, digest, "--source", file.path]
        )
    }
}
