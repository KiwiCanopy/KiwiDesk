import Foundation
import Testing

/// `changelog.yml` writes Sparkle's feed from the PUBLISHED
/// release and opens the PR that takes it live (#874).
///
/// Split from the signing half because the two workflows fail
/// differently and share no state: a signing regression ships a
/// release nobody is offered, while a publishing regression
/// ships a feed that describes the wrong thing — or never
/// reaches `main` at all.
///
/// **What this cannot see**: whether Cloudflare actually
/// redeploys the merged feed. That is a hosting setting rather
/// than a file.
@Suite("Appcast publish workflow (#874)")
struct AppcastPublishWorkflowTests {
    private func workflow(_ name: String) throws -> String {
        try workflowSource(name)
    }

    // MARK: - changelog.yml publishes it

    @Test("the sync workflow writes the feed on publish")
    func syncWorkflowWritesTheFeed() throws {
        let yaml = try workflow("changelog.yml")
        #expect(yaml.contains("scripts/appcast-sync --all"))
        #expect(yaml.contains("release:\n    types: [published]"))
    }

    /// `--all` skips a release it cannot offer with a printed
    /// reason, which is right for history and useless for the
    /// release that just went out. Held strictly, a publish whose
    /// signing failed reds and names why; without it, that run
    /// writes a feed silently missing the newest version and
    /// reports success.
    @Test("the just-published release is held strictly")
    func publishedReleaseIsCheckedStrictly() throws {
        let yaml = try workflow("changelog.yml")
        // The whole invocation. A bare `--check` needle was
        // decoration: `changelog-sync --release "$TAG" --check`
        // sits four lines above and kept it matched with the
        // appcast pass deleted outright.
        #expect(
            yaml.contains(
                #"appcast-sync --release "$PUBLISHED""#
            ),
            "the published tag must be held to every clause"
        )
        #expect(
            yaml.contains(
                "PUBLISHED: ${{ github.event.release.tag_name }}"
            ),
            "the strict pass keys on the event's tag, not a dispatch"
        )
        #expect(
            !yaml.contains(
                #"appcast-sync --release "$PUBLISHED" --check"#
            ),
            "on a publish it must WRITE, not only verify"
        )
    }

    /// Both files in one commit. Split across two PRs, one can
    /// merge without the other and the site and the update window
    /// then describe different releases.
    @Test("the notes and the feed land in one commit")
    func bothArtifactsInOnePR() throws {
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains(
                "SYNCED=(site/src/data/changelog.json\n"
                    + "                  site/public/appcast.xml)"
            ),
            "both files must be in the one synced list"
        )
        #expect(yaml.contains(#"git add "${SYNCED[@]}""#))
    }

    /// A PR opened with `github.token` fires no workflows, so
    /// `site.yml` never runs on the sync PR — and `site.yml` is
    /// where the "is the feed actually served" check lives.
    /// Without this call the feed is the one artifact that
    /// reaches `main` with its own guard never having read it.
    @Test("the sync PR runs the site gate before it exists")
    func syncPRRunsTheSiteGate() throws {
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains(
                "python3 ../scripts/check-site-tokens.py --dist dist"
            ),
            "the feed's own guard must run before the PR opens"
        )
    }

    /// The shipped feed URL and the file the sync writes must
    /// name the same thing.
    ///
    /// This deliberately does NOT open the feed. `site/**` is on
    /// `.github/ci-ignore.txt`, so a change confined to the site
    /// skips the macOS jobs — and a suite that reads a path CI
    /// hides from it is a guard that cannot fire for the edit it
    /// watches, which `CiPathFilterTests` refuses outright. That
    /// half lives in `scripts/check-site-tokens.py`, which
    /// `site.yml` runs on every `site/**` PR against the BUILT
    /// output. What is left here is the half whose inputs CI does
    /// read: the packager and the workflow.
    @Test("the shipped URL names the file the sync writes")
    func shippedURLNamesTheSyncedFile() throws {
        guard let url = try buildAppPlistValue("SUFeedURL"),
            !url.isEmpty
        else {
            Issue.record("build-app.sh declares no SUFeedURL")
            return
        }
        guard let name = url.split(separator: "/").last else {
            Issue.record("SUFeedURL has no filename: \(url)")
            return
        }
        #expect(
            url.hasPrefix("https://"),
            "an update feed is fetched over TLS or not at all"
        )
        let yaml = try workflow("changelog.yml")
        #expect(
            yaml.contains("/\(name))"),
            "the synced path must end in the shipped feed's name"
        )
    }
}
