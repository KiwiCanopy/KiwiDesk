import Foundation
import Testing

/// `scripts/appcast-sync` decides what an installed KiwiDesk is
/// offered as an update (#874), so every refusal it documents is
/// a case that must actually red.
///
/// The stakes differ from `ChangelogParserTests`' by one step: a
/// body that parses badly shows a poor page, while an item that
/// should not be in the feed is an update every installed copy
/// downloads and fails to install — and one that should be there
/// and is missing is an update path that silently never runs.
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* calls the second unrecoverable.
///
/// Driven through `--releases <file>`, which renders from a JSON
/// fixture and touches neither the network nor `gh`. The real
/// script runs in place: it reads `scripts/build-app.sh` for the
/// system-version floor and `site/src/data/changelog.json` for
/// the notes, and both are properties of the tree rather than of
/// the fixture.
@Suite("Appcast generator (#874)")
struct AppcastParserTests {
    private func script() -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("appcast-sync")
    }

    /// A 64-byte Ed25519 signature, base64. Built rather than
    /// pasted, so the length assertion the script makes is
    /// satisfied by construction and a future change to
    /// `_SIGNATURE_BYTES` fails loudly here instead of silently
    /// accepting a literal that no longer matches.
    private static let signature = Data(
        repeating: 0x41,
        count: 64
    ).base64EncodedString()

    /// One published release carrying a notarized archive and its
    /// sidecar — the shape every case below is a mutation of.
    private static func release(
        tag: String = "v0.9.8",
        assets: [[String: Any]]? = nil,
        signature: String = AppcastParserTests.signature,
        draft: Bool = false
    ) -> [String: Any] {
        let version =
            tag.hasPrefix("v")
            ? String(tag.dropFirst()) : tag
        let name = "KiwiDesk-\(version).zip"
        return [
            "tag_name": tag,
            "published_at": "2026-08-26T10:00:00Z",
            "draft": draft,
            "edsig": signature,
            "assets": assets ?? [
                [
                    "name": name,
                    "size": 9_123_456,
                    "browser_download_url":
                        "https://github.com/KiwiCanopy/KiwiDesk"
                        + "/releases/download/\(tag)/\(name)",
                    "url": "https://api.github.com/assets/1",
                ],
                [
                    "name": "\(name).edsig",
                    "size": 89,
                    "url": "https://api.github.com/assets/2",
                ],
            ],
        ]
    }

    private static func asset(
        _ name: String,
        size: Int = 9_123_456
    ) -> [String: Any] {
        [
            "name": name,
            "size": size,
            "browser_download_url": "https://example.invalid/\(name)",
            "url": "https://api.github.com/assets/9",
        ]
    }

    private func render(
        _ releases: [[String: Any]]
    ) throws -> ScriptRun {
        let data = try JSONSerialization.data(
            withJSONObject: releases
        )
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "appcast-releases-\(UUID().uuidString).json"
            )
        try data.write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: script(),
            arguments: ["--releases", file.path]
        )
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
                "<sparkle:version>0.9.8</sparkle:version>"
            )
        )
        #expect(
            run.stdout.contains(
                #"sparkle:edSignature="\#(Self.signature)""#
            )
        )
        #expect(run.stdout.contains(#"length="9123456""#))
    }

    /// The enclosure URL is the published download, never the
    /// API's asset route — an installed copy fetches it with no
    /// credentials at all.
    @Test("the enclosure points at the public download")
    func enclosureIsThePublicURL() throws {
        let run = try render([Self.release()])
        #expect(
            run.stdout.contains(
                "https://github.com/KiwiCanopy/KiwiDesk/releases"
                    + "/download/v0.9.8/KiwiDesk-0.9.8.zip"
            )
        )
        #expect(!run.stdout.contains("api.github.com"))
    }

    /// No version cutoff exists anywhere in the script, and this
    /// is what says so: a release numbered below every shipped
    /// one is still offered when it satisfies the clauses. The
    /// releases that predate Sparkle drop out because they have
    /// no sidecar, which is a property of their DATA — a number
    /// written into the generator would be a second thing to
    /// remember to bump.
    @Test("no version is special-cased")
    func noVersionCutoff() throws {
        let run = try render([Self.release(tag: "v0.0.1")])
        #expect(run.status == 0)
        #expect(
            run.stdout.contains(
                "<sparkle:version>0.0.1</sparkle:version>"
            )
        )
    }

    /// The floor is `build-app.sh`'s `LSMinimumSystemVersion`,
    /// read rather than restated. Derived here the same way, so
    /// a raise to macOS 15 that touched only the script cannot
    /// leave this suite agreeing with a stale literal.
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

    // MARK: - Refusals

    @Test("a draft is never offered")
    func draftRefused() throws {
        let run = try render([Self.release(draft: true)])
        #expect(run.status != 0)
        #expect(run.stderr.contains("still a draft"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("an un-notarized archive is never offered")
    func unnotarizedRefused() throws {
        let run = try render([
            Self.release(assets: [
                Self.asset("KiwiDesk-0.9.8-unnotarized.zip"),
                Self.asset(
                    "KiwiDesk-0.9.8-unnotarized.zip.edsig",
                    size: 89
                ),
            ])
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("not notarized"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("an archive with no signature is never offered")
    func missingSidecarRefused() throws {
        let run = try render([
            Self.release(assets: [
                Self.asset("KiwiDesk-0.9.8.zip")
            ])
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("KiwiDesk-0.9.8.zip.edsig"))
        #expect(!run.stdout.contains("<item>"))
    }

    @Test("a signature that is not base64 is refused")
    func malformedSignatureRefused() throws {
        let run = try render([
            Self.release(signature: "this is not base64 !!")
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("not base64"))
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
        #expect(run.status != 0)
        #expect(run.stderr.contains("32 bytes"))
    }

    @Test("an empty signature is refused")
    func emptySignatureRefused() throws {
        let run = try render([Self.release(signature: "")])
        #expect(run.status != 0)
        #expect(run.stderr.contains("is empty"))
    }

    @Test("a release with no archive is not offered")
    func noArchiveRefused() throws {
        let run = try render([
            Self.release(assets: [Self.asset("notes.txt")])
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("no .zip asset"))
    }

    /// Two shippable archives is the per-architecture case the
    /// release workflow already anticipates. Guessing between
    /// them would send half the users the wrong build, so it
    /// refuses until someone decides.
    @Test("two distributable archives refuse rather than guess")
    func ambiguousArchiveRefused() throws {
        let run = try render([
            Self.release(assets: [
                Self.asset("KiwiDesk-0.9.8.zip"),
                Self.asset("KiwiDesk-0.9.8-arm64.zip"),
                Self.asset("KiwiDesk-0.9.8.zip.edsig", size: 89),
            ])
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("2 distributable"))
    }

    @Test("a zero-length archive is refused")
    func zeroLengthRefused() throws {
        let run = try render([
            Self.release(assets: [
                Self.asset("KiwiDesk-0.9.8.zip", size: 0),
                Self.asset("KiwiDesk-0.9.8.zip.edsig", size: 89),
            ])
        ])
        #expect(run.status != 0)
        #expect(run.stderr.contains("size of"))
    }

    // MARK: - One bad release does not take the feed with it

    /// The refusals above are per-release. A feed that dropped
    /// every item because one historical release lacks a sidecar
    /// would strand everyone, so the good release still renders.
    @Test("a refused release does not remove a good one")
    func oneRefusalKeepsTheRest() throws {
        let run = try render([
            Self.release(tag: "v0.9.8"),
            Self.release(
                tag: "v0.9.7",
                assets: [Self.asset("KiwiDesk-0.9.7.zip")]
            ),
        ])
        #expect(run.status != 0)
        #expect(
            run.stdout.contains(
                "<sparkle:version>0.9.8</sparkle:version>"
            )
        )
        #expect(
            !run.stdout.contains(
                "<sparkle:version>0.9.7</sparkle:version>"
            )
        )
    }
}
