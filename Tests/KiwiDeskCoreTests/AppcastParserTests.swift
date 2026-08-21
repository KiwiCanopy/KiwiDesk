import Foundation
import Testing

/// What `scripts/appcast-sync` will and will not offer as an
/// update (#874).
///
/// The stakes differ from `ChangelogParserTests`' by one step: a
/// body that parses badly shows a poor page, while an item that
/// should not be in the feed is an update every installed copy
/// downloads and then refuses — and one that should be there and
/// is missing is an update path that silently never runs.
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* calls the second unrecoverable.
///
/// Driven through `--releases <fixture> --all --output -`, which
/// reads the releases from disk and renders to stdout, touching
/// neither the network nor `gh`. `AppcastModeTests` covers the
/// other half — that `--all` TOLERATES what `--release` refuses.
///
/// **Fixture tags are `v9999.*` deliberately.** The script runs
/// in place and reads the repo's real
/// `site/src/data/changelog.json` for its notes, so a fixture
/// borrowing a plausible version number would silently start
/// rendering release prose into the output these assertions
/// inspect (`.claude/rules/tests.md` ▸ pin any default a fixture
/// reasons from). No release can ever carry these.
@Suite("Appcast offerability (#874)")
struct AppcastParserTests {
    static let fixtureTag = "v9999.0.1"
    static let fixtureVersion = "9999.0.1"

    /// A 64-byte Ed25519 signature, base64. Built rather than
    /// pasted, so a change to the script's expected length reds
    /// here instead of silently accepting a stale literal.
    static let signature = Data(repeating: 0x41, count: 64)
        .base64EncodedString()

    /// The shape every case below is a mutation of: one
    /// published release with a notarized archive and its
    /// sidecar.
    static func release(
        tag: String = AppcastParserTests.fixtureTag,
        assets: [[String: Any]]? = nil,
        signature: String = AppcastParserTests.signature,
        draft: Bool = false
    ) -> [String: Any] {
        let version =
            tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let name = "KiwiDesk-\(version).zip"
        return [
            "tag_name": tag,
            "published_at": "2026-08-26T10:00:00Z",
            "draft": draft,
            "edsig": signature,
            "assets": assets ?? [
                asset(name),
                asset("\(name).edsig", size: 89),
            ],
        ]
    }

    static func asset(
        _ name: String,
        size: Int = 9_123_456
    ) -> [String: Any] {
        [
            "name": name,
            "size": size,
            "browser_download_url":
                "https://github.com/KiwiCanopy/KiwiDesk/releases"
                + "/download/\(fixtureTag)/\(name)",
            "url": "https://api.github.com/assets/9",
        ]
    }

    /// Renders a fixture through the real script.
    static func render(
        _ releases: [[String: Any]],
        arguments: [String] = ["--all"]
    ) throws -> ScriptRun {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-releases-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: releases)
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("appcast-sync"),
            arguments: ["--releases", file.path]
                + arguments + ["--output", "-"]
        )
    }

    private func render(
        _ releases: [[String: Any]]
    ) throws -> ScriptRun {
        try Self.render(releases)
    }

    // MARK: - The shape that must NOT be refused

    /// A guard that rejects legitimate input gets switched off,
    /// so this is asserted before any refusal below.
    @Test("a signed, notarized, published release is offered")
    func validReleaseIsOffered() throws {
        let run = try render([Self.release()])
        #expect(run.status == 0)
        #expect(run.stdout.contains("<item>"))
        #expect(
            run.stdout.contains(
                "<sparkle:version>\(Self.fixtureVersion)"
                    + "</sparkle:version>"
            )
        )
        #expect(
            run.stdout.contains(
                #"sparkle:edSignature="\#(Self.signature)""#
            )
        )
        #expect(run.stdout.contains(#"length="9123456""#))
    }

    /// The enclosure is the published download an installed copy
    /// fetches with no credentials — never the API asset route,
    /// which needs auth.
    @Test("the enclosure points at the public download")
    func enclosureIsThePublicURL() throws {
        let run = try render([Self.release()])
        #expect(
            run.stdout.contains(
                "https://github.com/KiwiCanopy/KiwiDesk/releases"
                    + "/download/\(Self.fixtureTag)/"
            )
        )
        #expect(!run.stdout.contains("api.github.com"))
    }

    /// No version cutoff exists in the script and none should:
    /// the releases that predate the updater drop out because
    /// they have no sidecar, which is a property of their DATA.
    /// A number written into the generator would be a second
    /// thing to remember to bump.
    @Test("no version is special-cased")
    func noVersionCutoff() throws {
        let run = try render([Self.release(tag: "v9999.0.2")])
        #expect(run.status == 0)
        #expect(
            run.stdout.contains(
                "<sparkle:version>9999.0.2</sparkle:version>"
            )
        )
    }

    /// The floor and the feed's own link both come from the
    /// packager, read rather than restated.
    @Test("the system floor is read from build-app.sh")
    func floorComesFromTheBuildScript() throws {
        guard
            let floor = try buildAppPlistValue(
                "LSMinimumSystemVersion"
            ), !floor.isEmpty
        else {
            Issue.record(
                "build-app.sh declares no LSMinimumSystemVersion"
            )
            return
        }
        let run = try render([Self.release()])
        #expect(
            run.stdout.contains(
                "<sparkle:minimumSystemVersion>\(floor)"
                    + "</sparkle:minimumSystemVersion>"
            )
        )
    }

    @Test("the channel link is the shipped feed URL")
    func channelLinkIsTheShippedURL() throws {
        guard let url = try buildAppPlistValue("SUFeedURL") else {
            Issue.record("build-app.sh declares no SUFeedURL")
            return
        }
        let run = try render([Self.release()])
        #expect(run.stdout.contains("<link>\(url)</link>"))
    }

    // MARK: - Refusals

    /// Asserts the REASON, not just the absence of an item.
    /// An earlier cut asserted only "no item", which a second
    /// draft filter one layer up satisfied — so the rule this
    /// names could be deleted outright and the guard stayed
    /// green.
    @Test("a draft is never offered, and says why")
    func draftRefused() throws {
        let run = try render([Self.release(draft: true)])
        #expect(run.stderr.contains("still a draft"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("an un-notarized archive is never offered")
    func unnotarizedRefused() throws {
        let name = "KiwiDesk-\(Self.fixtureVersion)-unnotarized.zip"
        let run = try render([
            Self.release(assets: [
                Self.asset(name),
                Self.asset("\(name).edsig", size: 89),
            ])
        ])
        #expect(run.stderr.contains("not notarized"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("an archive with no signature is never offered")
    func missingSidecarRefused() throws {
        let run = try render([
            Self.release(assets: [
                Self.asset("KiwiDesk-\(Self.fixtureVersion).zip")
            ])
        ])
        #expect(run.stderr.contains(".edsig"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("a signature that is not base64 is refused")
    func malformedSignatureRefused() throws {
        let run = try render([
            Self.release(signature: "this is not base64 !!")
        ])
        #expect(run.stderr.contains("not base64"))
        #expect(!run.stdout.contains("<item>"))
    }

    /// A base64 string of the wrong length is the case a shape
    /// check catches and a "looks like base64" check does not —
    /// and Sparkle would only reject it on the user's machine.
    @Test("a signature of the wrong length is refused")
    func shortSignatureRefused() throws {
        let run = try render([
            Self.release(
                signature: Data(repeating: 0x41, count: 32)
                    .base64EncodedString()
            )
        ])
        #expect(run.stderr.contains("32 bytes"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("an empty signature is refused")
    func emptySignatureRefused() throws {
        let run = try render([Self.release(signature: "")])
        #expect(run.stderr.contains("is empty"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("a release with no archive is not offered")
    func noArchiveRefused() throws {
        let run = try render([
            Self.release(assets: [Self.asset("notes.txt")])
        ])
        #expect(run.stderr.contains("no .zip asset"))
        #expect(!run.stdout.contains("<item>"))
    }

    /// Two shippable archives is the per-architecture case the
    /// release workflow already anticipates. Guessing between
    /// them would send half the users the wrong build.
    @Test("two distributable archives refuse rather than guess")
    func ambiguousArchiveRefused() throws {
        let base = "KiwiDesk-\(Self.fixtureVersion)"
        let run = try render([
            Self.release(assets: [
                Self.asset("\(base).zip"),
                Self.asset("\(base)-arm64.zip"),
                Self.asset("\(base).zip.edsig", size: 89),
            ])
        ])
        #expect(run.stderr.contains("2 distributable"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("a zero-length archive is refused")
    func zeroLengthRefused() throws {
        let base = "KiwiDesk-\(Self.fixtureVersion)"
        let run = try render([
            Self.release(assets: [
                Self.asset("\(base).zip", size: 0),
                Self.asset("\(base).zip.edsig", size: 89),
            ])
        ])
        #expect(run.stderr.contains("size of"))
        #expect(!run.stdout.contains("<item>"))
    }
}
