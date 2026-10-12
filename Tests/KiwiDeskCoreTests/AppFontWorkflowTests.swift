import Foundation
import Testing

/// The weekly app-font watch cannot go quietly inert.
///
/// `.github/workflows/app-font.yml` runs
/// `scripts/update-app-font.sh` and opens a PR. Every failure mode
/// here is silent — a cron workflow that stops producing PRs looks
/// exactly like an upstream that stopped releasing, and nobody
/// checks a green Actions tab for something that did not happen.
///
/// Three couplings, each of which a normal edit can break without
/// breaking anything that reports:
///
/// 1. The workflow calls the script. A second copy of the
///    vendoring logic inline in YAML would drift from the one the
///    developer runs by hand, and only the hand path is ever
///    watched.
/// 2. The check job's `sed` reads the pinned tag out of
///    `UPSTREAM.md` — a file the *script* writes. The two formats
///    are one hand-written pair: reword that heredoc and the read
///    yields empty, which compares unequal to every upstream tag,
///    so the expensive job runs every week forever.
/// 3. The PR is opened with the owner's PAT (`RELEASE_SYNC_TOKEN`,
///    #1154's token), so `pull_request` fires and ci.yml is the
///    gate — and only the PR step holds it, never a step that runs
///    the tree's code. Without the secret the PR falls back to
///    `GITHUB_TOKEN`, which fires nothing, so the drop is validated
///    before the PR exists on that path alone — dropping the test
///    step there would hand the reviewer an unverified drop with
///    no red anywhere.
///
/// **What this cannot see**: whether the cron fires at all (GitHub
/// disables schedules after 60 days of repo inactivity), and
/// whether the repo still permits Actions to open PRs. Both are
/// settings, not files.
@Suite("App font update workflow")
struct AppFontWorkflowTests {
    var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // KiwiDeskCoreTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repo root
    }

    private func read(_ components: String...) throws -> String {
        var url = repoRoot
        for component in components {
            url.appendPathComponent(component)
        }
        return try String(contentsOf: url, encoding: .utf8)
    }

    var workflow: String {
        get throws {
            try read(".github", "workflows", "app-font.yml")
        }
    }

    @Test("The workflow vendors through the script")
    func vendorsThroughTheScript() throws {
        let yaml = try workflow
        #expect(
            yaml.contains("./scripts/update-app-font.sh"),
            """
            app-font.yml no longer runs the vendoring script — an \
            inline copy drifts from the path a developer runs
            """
        )
        // The assets are named in the script, not here. A workflow
        // reaching for a release asset itself is that second copy.
        #expect(
            !yaml.contains("gh release download"),
            "app-font.yml downloads assets behind the script's back"
        )
    }

    @Test("The expensive job is gated on the cheap check")
    func macOsJobIsGated() throws {
        let yaml = try workflow
        #expect(
            yaml.contains("needs: check"),
            "the macOS job no longer depends on the check job"
        )
        #expect(
            yaml.contains("if: needs.check.outputs.run == 'true'"),
            "the macOS job is not gated on the check outcome"
        )
    }

    @Test("The drop is tested before the PR is opened")
    func testsPrecedeThePullRequest() throws {
        let yaml = try workflow
        // `run: swift test`, not `swift test`: the PR body the
        // last step writes *names* the commands it ran, and that
        // prose sits ahead of `gh pr create` in the same file — so
        // the bare needle stayed green with the Test step deleted.
        let test = try #require(
            yaml.range(of: "run: swift test"),
            "app-font.yml no longer runs the suite"
        )
        let create = try #require(
            yaml.range(of: "gh pr create"),
            "app-font.yml no longer opens a PR"
        )
        #expect(
            test.lowerBound < create.lowerBound,
            """
            the PR is opened before the suite runs — CI never fires \
            on a GITHUB_TOKEN PR, so nothing else would catch a bad \
            drop
            """
        )
        // Skipped only where the PAT opens the PR and ci.yml runs.
        let gated = "if: env.HAS_SYNC_TOKEN != 'true'\n        run: swift test"
        #expect(
            yaml.contains(gated),
            "the suite is no longer gated on the token fallback"
        )
        #expect(
            yaml.contains(
                "HAS_SYNC_TOKEN: ${{ secrets.RELEASE_SYNC_TOKEN != '' }}"
            ),
            "the fallback gate no longer reads the secret's presence"
        )
    }

    /// The PAT opens the PR — or nothing fires on it — and nothing
    /// but the PR step holds it: the checkout persists no
    /// credential, so `swift build` and the vendoring script run
    /// without it.
    @Test("Only the PR step holds the PAT")
    func patStaysInThePullRequestStep() throws {
        // Comments dropped: the header names the secret in prose.
        let yaml = try workflow.split(separator: "\n")
            .filter { !$0.trimmingCharacters(in: .whitespaces).hasPrefix("#") }
            .joined(separator: "\n")
        let token = "${{ secrets.RELEASE_SYNC_TOKEN || github.token }}"
        // The presence flag and the PR step's token.
        #expect(
            yaml.components(separatedBy: "RELEASE_SYNC_TOKEN").count
                - 1 == 2,
            "RELEASE_SYNC_TOKEN reaches a step beyond the PR's"
        )
        let pat = try #require(
            yaml.range(of: "GH_TOKEN: \(token)"),
            "the PR is no longer opened with the PAT"
        )
        let create = try #require(yaml.range(of: "gh pr create"))
        let step = try #require(
            yaml.range(of: "- name: Open the pull request")
        )
        #expect(step.upperBound < pat.lowerBound)
        #expect(pat.upperBound < create.lowerBound)
        #expect(
            yaml.contains("persist-credentials: false"),
            "the checkout persists a credential the build could read"
        )
    }

    /// The pair that fails silently in the direction of *more*
    /// work: an unreadable pin never equals the upstream tag, so
    /// the workflow re-vendors every week and opens a PR whose own
    /// "identical assets" step then errors.
    @Test("The check job can still read the vendored tag")
    func vendoredTagIsReadable() throws {
        let yaml = try workflow
        let expression = "s/^- Release: //p"
        #expect(
            yaml.contains(expression),
            "the check job reads UPSTREAM.md some other way now"
        )

        // Apply the workflow's own expression to the real file.
        let upstream = try read(
            "Sources",
            "KiwiDeskCore",
            "Resources",
            "AppFont",
            "UPSTREAM.md"
        )
        let pinned =
            upstream
            .split(separator: "\n")
            .first { $0.hasPrefix("- Release: ") }
            .map { $0.dropFirst("- Release: ".count) }
            .map(String.init)
        let tag = try #require(
            pinned,
            """
            UPSTREAM.md has no `- Release: ` line — the check job \
            reads an empty pin and re-vendors forever
            """
        )
        // Same shape the script refuses to vendor, so a pin it
        // wrote always satisfies this.
        #expect(
            tag.range(
                of: "^v?[0-9][A-Za-z0-9._-]*$",
                options: .regularExpression
            ) != nil,
            "the pinned tag `\(tag)` is not a release tag"
        )
    }
}
