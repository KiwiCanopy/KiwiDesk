import Foundation
import Testing

/// The docs markers a release retires actually reach `main`, and
/// the plugin that draws them is exercised somewhere (#1232).
///
/// Split from `UnreleasedStripTests` because the two fail
/// differently and share no state: that suite holds what the
/// script does to a corpus, this holds whether the script's work
/// is wired to anything. A rewrite nobody commits is the failure
/// with no symptom at all — the job is green, the PR is opened,
/// and the site keeps badging behavior that shipped.
///
/// Scoped through `workflowSource` / `workflowStep` rather than a
/// reader of its own: `changelog.yml` argues this mechanism in
/// prose that names the very commands below, and a file-wide
/// needle would be satisfied by the comment arguing for the step
/// it is meant to find.
///
/// **What this cannot see**: whether the person reading the sync
/// PR acts on the list. That is the whole mitigation for a block
/// whose feature slipped OUT of the release it was unmarked by,
/// and it is a human step by design — see
/// `.claude/rules/site.md` ▸ *Unreleased docs mark themselves*.
@Suite("Unreleased marker workflow (#1232)")
struct UnreleasedStripWorkflowTests {
    private static let stripStep =
        "Retire the docs markers this release ships"
    private static let prStep =
        "Open a PR if anything moved, and let it land"

    @Test("The release sync retires the markers")
    func syncRunsTheStrip() throws {
        let yaml = try workflowSource("changelog.yml")
        let step = try workflowStep(Self.stripStep, in: yaml)
        #expect(
            step.contains("scripts/unreleased-strip"),
            """
            the sync no longer retires the docs markers — a \
            marker means "not in a release" only because this \
            ran at the last one (#1232)
            """
        )
        // On publish, which is when the claim becomes false.
        #expect(
            yaml.contains("release:\n    types: [published]"),
            "the sync no longer fires on publication"
        )
        // And ONLY on publish. `workflow_dispatch` is a rebuild —
        // of a refused body, or of the whole file — with nothing
        // published at that moment, so an ungated sweep unmarks
        // blocks that are genuinely unreleased and this job's own
        // auto-merge then lands them unattended. Polarity IS the
        // decision: an inverted condition reads as gated.
        #expect(
            step.contains("if: github.event_name == 'release'"),
            """
            the sweep is not gated on the release event — a \
            dispatch would unmark unreleased blocks and merge \
            that unattended (#1232)
            """
        )
    }

    @Test("The corpus is validated where a docs PR can see it")
    func siteGateValidatesTheCorpus() throws {
        // The release-time sweep is fail-fast AND sits in the
        // workflow that carries the appcast, so a malformed `:::`
        // reaching `main` would block the update feed on a docs
        // typo. `--check` on the site gate is what keeps that
        // sweep safe to leave fail-fast.
        let site = try workflowSource("site.yml")
        #expect(
            site.contains("scripts/unreleased-strip --check"),
            """
            site.yml no longer validates the marker grammar, so a \
            malformed block reaches main and fails the release \
            sync instead — with the appcast behind it (#1232)
            """
        )
        // It can only fire if the workflow runs for a docs edit,
        // which is the half that matters: the corpus lives under
        // `docs/**`. The site half is deliberately not asserted —
        // a literal opening with that directory's name is what
        // `CiPathFilterTests` refuses in a Swift suite.
        // BOTH triggers, counted. `push` and `pull_request`
        // carry their own `paths:`, and the one that matters is
        // `pull_request` — the check has to fire on the PR that
        // adds a malformed marker, not after it merges. Deleting
        // that one alone passed a single-occurrence clause.
        let docs = site.split(separator: "\n")
            .filter {
                $0.trimmingCharacters(in: .whitespaces)
                    == "- \"docs/**\""
            }
            .count
        #expect(
            docs == 2,
            """
            site.yml names docs/** \(docs)× — it needs one entry \
            under push and one under pull_request, or the corpus \
            check cannot fire for the edit it watches (#1232)
            """
        )
    }

    @Test("The site is built AFTER the markers are retired")
    func theBuildFollowsTheSweep() throws {
        // This ORDER is the whole coverage of one failure: the
        // sweep re-reads through the parser that did the rewrite,
        // so a grammar narrower than remark's is invisible to its
        // own postcondition. What catches it is
        // `check_unreleased_markers` comparing that parser's
        // count against the badges the real pipeline rendered —
        // which only says anything if the build runs on the SWEPT
        // corpus. Move the build above the sweep, or into another
        // job, and every other clause here stays green while the
        // coverage silently goes.
        let yaml = try workflowSource("changelog.yml")
        let lines = yaml.split(
            separator: "\n",
            omittingEmptySubsequences: false
        )
        let sweep = try #require(
            lines.firstIndex {
                $0.contains("- name: \(Self.stripStep)")
            },
            "the sweep step is gone"
        )
        let build = try #require(
            lines.firstIndex {
                $0.contains("check-site-tokens.py --dist dist")
            },
            """
            changelog.yml no longer runs the site gate, which is \
            the only thing that can see a sweep whose grammar is \
            narrower than remark's (#1232)
            """
        )
        #expect(
            sweep < build,
            """
            the site gate runs BEFORE the markers are retired, so \
            it measures the corpus the sweep has not touched yet \
            (#1232)
            """
        )
    }

    @Test("What the strip rewrote is what the PR carries")
    func sweptDocsAreCommitted() throws {
        let yaml = try workflowSource("changelog.yml")
        let step = try workflowStep(Self.prStep, in: yaml)
        // The coupling with no symptom: the script rewrites
        // `docs/` in the checkout, and a commit that stages only
        // the two generated site files drops every one of those
        // rewrites while the run stays green.
        #expect(
            try workflowArray("SYNCED", in: yaml).contains("docs"),
            """
            the sync PR stages the generated site files without \
            docs/ — the marker rewrites are discarded and the \
            job reports success (#1232)
            """
        )
        #expect(
            step.contains(#"git add "${SYNCED[@]}""#),
            "the staged set is no longer the SYNCED array"
        )
        #expect(
            step.contains(#"git diff --quiet -- "${SYNCED[@]}""#),
            """
            the "anything moved" test no longer reads the same \
            set it stages, so a docs-only sweep exits early and \
            opens no PR
            """
        )
    }

    @Test("The report the strip prints reaches the PR body")
    func theReportReachesThePullRequest() throws {
        let yaml = try workflowSource("changelog.yml")
        let strip = try workflowStep(Self.stripStep, in: yaml)
        let pr = try workflowStep(Self.prStep, in: yaml)
        // Read the path off the WRITING side and require it of
        // the reading one, rather than spelling it twice here: a
        // one-sided rename is otherwise silent, and what it
        // costs is the only place a wrongly unmarked block is
        // visible to a human.
        let written = try #require(
            strip.split(separator: "\n")
                .compactMap { line -> String? in
                    guard let tee = line.range(of: "tee ") else {
                        return nil
                    }
                    return line[tee.upperBound...]
                        .trimmingCharacters(in: .whitespaces)
                }
                .first,
            """
            the strip step no longer captures its report — the \
            list of unmarked blocks reaches nobody (#1232)
            """
        )
        #expect(
            pr.contains("cat \(written)"),
            """
            the PR body does not read \(written), so the blocks \
            this release unmarked are reported to nobody
            """
        )
        // Only when something was unmarked. A human reading that
        // list is this design's one net for a block whose feature
        // slipped out of the release, and a paragraph printed on
        // every release is what trains a reader to skip it.
        #expect(
            pr.contains("grep -q \"^  - \" \(written)"),
            """
            the unmarked-blocks paragraph is unconditional — \
            boilerplate on every sync is how the one net this \
            design has stops being read (#1232)
            """
        )
    }

    @Test("The plugin has a subject on the site gate")
    func siteGateRunsTheFixtures() throws {
        // The artifact clauses in check-site-tokens.py go vacuous
        // whenever the corpus carries no marker, which is most of
        // the time. Drop this step and the plugin is guarded by
        // nothing at all, on a green build.
        let site = try workflowSource("site.yml")
        #expect(
            site.contains("node test-unreleased.mjs"),
            """
            site.yml no longer runs the marker fixtures — with an \
            empty corpus nothing else exercises the plugin (#1232)
            """
        )
        // And on the release path, where site.yml never fires:
        // a PR opened with `github.token` triggers no workflows.
        let sync = try workflowSource("changelog.yml")
        #expect(
            sync.contains("node test-unreleased.mjs"),
            """
            the sync workflow does not run the marker fixtures, \
            and site.yml cannot see its PR (#1154)
            """
        )
    }
}
