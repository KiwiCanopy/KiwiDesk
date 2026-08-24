import Foundation
import Testing

/// The site's promoted download URL comes from a release's OWN
/// asset list (#904), never from a filename composed out of the
/// version.
///
/// Why that distinction earns a suite: the landing page renders a
/// first-class "Download for Mac" button from this field, and the
/// site deploys independently of any tag. A composed
/// `…/download/<tag>/KiwiDesk-<version>.dmg` is correct only while
/// the release workflow keeps building a disk image — one edit
/// away from a button that 404s, on a page nothing re-publishes.
/// `docs/design-decisions.md` ▸ *No distribution channel without
/// an update path* is the entry that argues the irreversibility: a
/// stranded downloader cannot be recovered.
///
/// Driven through `--all --releases <fixture> --output -`, the
/// seam `appcast-sync` already carries, so this touches neither
/// the network nor the repo's own generated file.
///
/// Tags are `v9999.*` for the reason `AppcastFixture` states: the
/// script runs in place, and a plausible version could collide
/// with real generated output.
@Suite("Changelog download URL (#904)")
struct ChangelogDownloadTests {
    private func script() -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("changelog-sync")
    }

    /// One published release carrying a curated block, plus
    /// whatever assets the case is about.
    private func release(
        assets: [[String: Any]]
    ) -> [String: Any] {
        [
            "tag_name": "v9999.0.1",
            "published_at": "2026-08-26T10:00:00Z",
            "draft": false,
            "html_url": "https://example.invalid/release",
            "body": """
            ## Highlights

            A summary sentence about the release.

            ### Bits

            - **A thing changed.** And here is how.
            """,
            "assets": assets,
        ]
    }

    private func asset(
        _ name: String,
        url: String
    ) -> [String: Any] {
        ["name": name, "browser_download_url": url]
    }

    /// Runs the generator over a fixture and hands back the one
    /// entry it produced.
    private func entry(
        assets: [[String: Any]]
    ) throws -> [String: Any] {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "changelog-releases-\(UUID().uuidString).json"
            )
        try JSONSerialization
            .data(withJSONObject: [release(assets: assets)])
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let run = try runPythonScript(
            at: script(),
            arguments: [
                "--all", "--releases", file.path, "--output", "-",
            ]
        )
        #expect(run.status == 0)
        let data = Data(run.stdout.utf8)
        let object =
            try JSONSerialization
            .jsonObject(with: data) as? [String: Any]
        let releases = object?["releases"] as? [[String: Any]]
        #expect(releases?.count == 1)
        return try #require(releases?.first)
    }

    @Test("a disk image is recorded by its own asset URL")
    func recordsTheAssetsOwnURL() throws {
        // The URL deliberately does NOT match the shape a
        // composed one would take. An implementation that built
        // `…/download/v9999.0.1/KiwiDesk-9999.0.1.dmg` from the
        // version would still produce a plausible string and
        // still pass a test that only checked for "a .dmg URL";
        // it cannot pass this one.
        let found = try entry(assets: [
            asset(
                "KiwiDesk-9999.0.1.dmg",
                url: "https://example.invalid/elsewhere/x.dmg"
            )
        ])
        #expect(
            found["download"] as? String
                == "https://example.invalid/elsewhere/x.dmg"
        )
    }

    @Test("no disk image means no download field at all")
    func absentWhereNoDiskImage() throws {
        // The safe degrade. The field must be ABSENT rather than
        // empty: the site tests for the key, and an empty string
        // that still exists reads differently to a presence check
        // than to a truthiness one.
        let found = try entry(assets: [
            asset(
                "KiwiDesk-9999.0.1.zip",
                url: "https://example.invalid/x.zip"
            ),
            asset(
                "KiwiDesk-9999.0.1.zip.edsig",
                url: "https://example.invalid/x.zip.edsig"
            ),
        ])
        #expect(found["download"] == nil)
    }

    @Test("an unnotarized image is refused, not ranked")
    func refusesUnnotarized() throws {
        // `release.yml` renames the notarized image ONTO the
        // plain name, so this sibling exists only when something
        // went wrong. Ranking it below the plain name would
        // publish it the first time it stood alone, and
        // Gatekeeper tells that downloader the app is damaged.
        let found = try entry(assets: [
            asset(
                "KiwiDesk-9999.0.1-unnotarized.dmg",
                url: "https://example.invalid/bad.dmg"
            )
        ])
        #expect(found["download"] == nil)
    }

    @Test("the notarized image wins when both are present")
    func prefersNotarizedOverUnnotarized() throws {
        let found = try entry(assets: [
            asset(
                "KiwiDesk-9999.0.1-unnotarized.dmg",
                url: "https://example.invalid/bad.dmg"
            ),
            asset(
                "KiwiDesk-9999.0.1.dmg",
                url: "https://example.invalid/good.dmg"
            ),
        ])
        #expect(
            found["download"] as? String
                == "https://example.invalid/good.dmg"
        )
    }
}
