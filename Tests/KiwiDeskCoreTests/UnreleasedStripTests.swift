import Foundation
import Testing

/// What `scripts/unreleased-strip` will and will not unmark
/// (#1232).
///
/// The stakes are the mirror of `ChangelogParserTests`'. A marker
/// left standing badges shipped behavior as unreleased; a marker
/// removed early presents unshipped behavior as shipped, with
/// nothing on the page to hint at it. `.claude/rules/site.md` ▸
/// *Unreleased docs mark themselves* argues why a sweep is what
/// retires the marker at all — the corpus IS the state, so its
/// rewrite has to be exact.
///
/// Driven through `sweepFixtureCorpus`, which runs the real
/// script over a throwaway tree. `UnreleasedStripGrammarTests`
/// holds the other half — what the parser accepts and refuses —
/// and the two were split on the §2.1 ceiling.
///
/// The fixtures spell `:::unreleased` by hand while the script
/// reads that name off `site/remark-unreleased.mjs`. **Do not
/// read that as this suite guarding the rename.** `site/**` is on
/// `.github/ci-ignore.txt`, so a PR touching only the plugin
/// skips both macOS jobs and this suite never runs for the edit
/// it would catch — the placement `CiPathFilterTests` refuses,
/// invisible to it here because the value arrives through a
/// script this suite shells out to rather than through a literal
/// it spells. What DOES catch a rename is the site gate, which
/// `docs/**` and `site/**` both trigger: `unreleased-strip
/// --check` refuses an opener that is neither the plugin's
/// current name nor a Starlight aside, so every marker left in
/// the corpus under the old spelling reds there. On an empty
/// corpus nothing catches it, and nothing is at stake.
@Suite("Unreleased marker strip (#1232)")
struct UnreleasedStripTests {
    private static let marked = """
        Intro.

        :::unreleased
        Each Desktop owns its own Spaces.

        A second paragraph.
        :::

        Tail.
        """

    @Test("A marked block loses its fences and keeps its prose")
    func unmarksAndKeepsTheBody() throws {
        let swept = try sweepFixtureCorpus(["a.md": Self.marked])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        let after = swept.pages["a.md"] ?? ""
        #expect(
            !after.contains(":::"),
            "a fence survived the rewrite:\n\(after)"
        )
        // Every line, not just the block's first: a sweep that
        // dropped the block wholesale would satisfy a clause that
        // only asked whether the fences were gone.
        for line in [
            "Intro.",
            "Each Desktop owns its own Spaces.",
            "A second paragraph.",
            "Tail.",
        ] {
            #expect(
                after.contains(line),
                "the rewrite lost `\(line)`:\n\(after)"
            )
        }
    }

    @Test("It reports the block it unmarked, by file and opener")
    func reportsWhatItUnmarked() throws {
        let swept = try sweepFixtureCorpus(["sub/a.md": Self.marked])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        // Both halves: the sync PR's reader has to find the
        // paragraph before they can judge whether unmarking it
        // was right, and a path alone does not locate it.
        #expect(
            swept.run.stdout.contains("sub/a.md"),
            "the report names no file:\n\(swept.run.stdout)"
        )
        #expect(
            swept.run.stdout.contains(
                "Each Desktop owns its own Spaces."
            ),
            "the report names no block:\n\(swept.run.stdout)"
        )
    }

    @Test("A marker in a code fence is an example, not a marker")
    func leavesFencedExamplesAlone() throws {
        let page = """
            Quoting the syntax:

            ```md
            :::unreleased
            example
            :::
            ```

            Done.
            """
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            """
            a documented example was rewritten:
            \(swept.pages["a.md"] ?? "")
            """
        )
        #expect(
            swept.run.stdout.contains("no :::unreleased marker"),
            "an example was counted:\n\(swept.run.stdout)"
        )
    }

    @Test("A real marker beside a fenced example is still swept")
    func sweepsPastAnExample() throws {
        // The pair, because either clause passes alone on a sweep
        // that gave up at the first fence — and one that did
        // would quietly stop retiring markers on any page that
        // documents anything.
        let page = """
            ```md
            :::unreleased
            example
            :::
            ```

            :::unreleased
            The real one.
            :::
            """
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        let after = swept.pages["a.md"] ?? ""
        #expect(
            after.contains("```md\n:::unreleased\nexample\n:::\n```"),
            "the example lost its fences:\n\(after)"
        )
        #expect(
            after.contains("The real one."),
            "the real block lost its prose:\n\(after)"
        )
        #expect(
            !after.contains(":::unreleased\nThe real one."),
            "the real marker survived:\n\(after)"
        )
    }

    @Test("An unclosed marker is refused, not swept past")
    func refusesAnUnclosedBlock() throws {
        // Without this the opener swallows the rest of the page:
        // every following line reads as inside the block, and the
        // sweep deletes the next `:::` it meets — which may be
        // another marker's closing fence.
        let swept = try sweepFixtureCorpus([
            "a.md": ":::unreleased\nNo closing fence.\n"
        ])
        #expect(
            swept.run.status != 0,
            "an unclosed block was accepted:\n\(swept.run.stdout)"
        )
        #expect(
            swept.run.stderr.contains("unclosed"),
            """
            the refusal does not say what is wrong:
            \(swept.run.stderr)
            """
        )
    }

    @Test("--check reports without writing")
    func checkModeWritesNothing() throws {
        let swept = try sweepFixtureCorpus(
            ["a.md": Self.marked],
            check: true
        )
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.run.stdout.contains(
                "Each Desktop owns its own Spaces."
            ),
            "--check reported nothing:\n\(swept.run.stdout)"
        )
        #expect(
            swept.pages["a.md"] == Self.marked,
            """
            --check rewrote the page:
            \(swept.pages["a.md"] ?? "")
            """
        )
    }
}
