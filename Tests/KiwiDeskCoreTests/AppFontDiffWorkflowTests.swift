import Foundation
import Testing

/// The app-font PR's look verdict cannot go quietly wrong.
///
/// `.github/workflows/app-font.yml` runs `scripts/app-font-diff`
/// on the base branch's font and the new one; the verdict decides
/// whether the PR is labelled `app-font: additions only` and may
/// land on green, or waits for the owner's look. Each coupling
/// below fails toward a wrong label, which no run reports:
///
/// 1. The workflow runs the script, with fontTools pinned, and
///    reads its `look=` line from the step it names.
/// 2. Only an explicit `false` labels: an empty verdict (a renamed
///    step, a dropped print, a failed diff) must ask, never pass,
///    and a failed diff still opens the PR.
/// 3. The label the workflow applies is the one the script's PR
///    text promises.
/// 4. The release notes start at the tag the check job read off
///    `UPSTREAM.md`.
/// 5. The workflow never merges or arms auto-merge: the
///    orchestrator lands the PR.
///
/// **What this cannot see**: the verdict itself, which
/// `AppFontDiffScriptTests` drives through the script's font-free
/// model; nor the font reading (the `liga` shaping, the outline
/// signatures), which needs fontTools the test runner lacks — a
/// change there owes a run by hand against real upstream drops.
@Suite("App font diff in the update workflow")
struct AppFontDiffWorkflowTests {
    static let label = "app-font: additions only"

    var yaml: String {
        get throws { try workflowSource("app-font.yml") }
    }

    var diffStep: String {
        get throws { try workflowStep("Diff the glyphs", in: yaml) }
    }

    var prStep: String {
        get throws {
            try workflowStep("Open the pull request", in: yaml)
        }
    }

    var script: String {
        get throws {
            try String(
                contentsOf: scriptFixtureRepoRoot()
                    .appendingPathComponent("scripts/app-font-diff"),
                encoding: .utf8
            )
        }
    }

    @Test("The workflow diffs through the script, fontTools pinned")
    func diffsThroughTheScript() throws {
        let step = try diffStep
        #expect(
            step.contains("venv/bin/python\" scripts/app-font-diff"),
            "the diff step no longer runs scripts/app-font-diff"
        )
        #expect(
            step.range(
                of: #"FONTTOOLS: fonttools==\d+\.\d+\.\d+\n"#,
                options: .regularExpression
            ) != nil,
            "fontTools is no longer pinned to an exact version"
        )
        #expect(
            step.contains("pip\" install --quiet \"$FONTTOOLS\""),
            "the diff step installs something other than the pin"
        )
        // Tree code runs here: github.token, never the PAT.
        #expect(step.contains("GH_TOKEN: ${{ github.token }}"))
        #expect(!step.contains("RELEASE_SYNC_TOKEN"))
        let path = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/app-font-diff").path
        #expect(
            FileManager.default.isExecutableFile(atPath: path),
            "scripts/app-font-diff is not executable"
        )
    }

    @Test("The verdict reaches the PR step, and only false labels")
    func verdictLabelsOnlyWhenExplicit() throws {
        let source = try yaml
        let diff = try #require(
            source.range(of: "- name: Diff the glyphs")
        )
        let create = try #require(source.range(of: "gh pr create"))
        #expect(diff.upperBound < create.lowerBound)
        // The output is read by id; a lost id reads empty.
        #expect(try diffStep.contains("id: diff\n"))
        #expect(
            try diffStep.contains("| tee -a \"$GITHUB_OUTPUT\""),
            "the script's look= line no longer reaches the output"
        )
        #expect(
            try script.contains("print(f\"look={"),
            "the script no longer prints the look= line"
        )
        let step = try prStep
        #expect(
            step.contains("LOOK: ${{ steps.diff.outputs.look }}"),
            "the PR step no longer reads the diff's verdict"
        )
        // Fail-closed: `!= "true"` would label an empty verdict.
        #expect(
            step.contains("if [ \"$LOOK\" = \"false\" ]; then"),
            "the label is no longer gated on an explicit false"
        )
        #expect(!step.contains("\"$LOOK\" != "))
    }

    /// A broken diff (a PyPI outage, a font fontTools refuses)
    /// must still open the PR, saying so, rather than lose the drop.
    @Test("A failed diff still opens an unlabelled PR")
    func failedDiffStillOpensThePullRequest() throws {
        #expect(
            try diffStep.contains("continue-on-error: true\n"),
            "a failed diff now fails the job before the PR exists"
        )
        #expect(
            try prStep.contains("**The glyph diff failed in"),
            "the PR no longer says its diff is missing"
        )
    }

    @Test("The applied label is the one the PR text names")
    func labelMatchesTheScript() throws {
        let step = try prStep
        #expect(
            step.contains("LABEL: '\(Self.label)'"),
            "app-font.yml applies a different label"
        )
        #expect(step.contains("--add-label \"$LABEL\""))
        #expect(
            try script.contains("`\(Self.label)`"),
            "the script's PR text names a different label"
        )
    }

    @Test("The notes start at the tag the check job read")
    func notesStartAtTheVendoredTag() throws {
        let source = try yaml
        #expect(
            source.contains(
                "vendored: ${{ steps.upstream.outputs.vendored }}"
            ),
            "the check job no longer exports the vendored tag"
        )
        let resolve = try workflowStep(
            "Resolve the upstream tag",
            in: source
        )
        #expect(
            resolve.contains("echo \"vendored=$vendored\""),
            "the check job no longer writes the vendored tag"
        )
        let step = try diffStep
        #expect(
            step.contains(
                "VENDORED: ${{ needs.check.outputs.vendored }}"
            )
        )
        #expect(
            step.contains("--from \"$VENDORED\" --to \"$TAG\""),
            "the notes no longer span vendored → new tag"
        )
    }

    @Test("The workflow never merges its own PR")
    func neverMerges() throws {
        let source = try yaml
        let needles = [
            "gh pr merge", "--auto", "auto-merge", "/merge",
            "enablePullRequestAutoMerge",
        ]
        for needle in needles {
            #expect(
                !source.contains(needle),
                "app-font.yml reaches for `\(needle)`"
            )
        }
    }
}
