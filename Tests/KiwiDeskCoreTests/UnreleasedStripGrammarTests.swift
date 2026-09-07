import Foundation
import Testing

/// `scripts/unreleased-strip` parses the grammar remark actually
/// has, and refuses what it cannot place (#1232).
///
/// Split from `UnreleasedStripTests` on the §2.1 ceiling. That
/// suite holds the sweep's CONTRACT — what it removes, what it
/// reports, what `--check` does. This one holds its GRAMMAR, and
/// the split is worth having on its own: every case below was
/// run through the installed remark-parse + remark-directive
/// before it was written here, because this script REWRITES
/// published prose and a parser that merely looks right rewrites
/// the wrong lines.
///
/// `guard-prover` found all of these vacuous before they existed:
/// deleting the nesting frame silently corrupted a page, dropping
/// the `~~~` alternative rewrote a documented example, and
/// removing the unknown-directive refusal was green here AND on
/// the site gate. Every fence spelling a clause names has a
/// fixture below — a claim about `~~~` with no `~~~` in the
/// corpus is the same green-on-nothing it was written to end
/// (code review, #1232).
@Suite("Unreleased marker grammar (#1232)")
struct UnreleasedStripGrammarTests {
    // MARK: - remark's grammar, measured 2026-09-07

    // The five cases below were run through the installed
    // remark-parse + remark-directive before being written here,
    // because this script REWRITES published prose and a parser
    // that merely looks right rewrites the wrong lines. Each
    // comment states what remark actually did.

    @Test("A longer outer fence nests, and only the marker's go")
    func nestsUnderALongerFence() throws {
        // remark: `unreleased@1-6`, `note@2-4`. The aside is
        // content of the marker, and the marker's own fences are
        // the outer pair.
        let page = """
            ::::unreleased
            :::note
            Nested aside.
            :::
            After the aside.
            ::::
            """
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        let after = swept.pages["a.md"] ?? ""
        #expect(
            after.contains(":::note\nNested aside.\n:::"),
            "the nested aside lost its fences:\n\(after)"
        )
        #expect(
            !after.contains("unreleased"),
            "the marker survived:\n\(after)"
        )
        #expect(
            after.contains("After the aside."),
            "content after the nested aside was lost:\n\(after)"
        )
    }

    @Test("An equal-length nest is refused, not guessed at")
    func refusesAnEqualLengthNest() throws {
        // remark: `unreleased@1-4`, `note@2-4` — ONE `:::` ends
        // both, and `After` + the trailing `:::` ship as prose.
        // Deleting that line to retire the marker would orphan
        // the aside, so this is refused rather than rewritten.
        let swept = try sweepFixtureCorpus([
            "a.md": """
            :::unreleased
            :::note
            Nested aside.
            :::
            After.
            :::
            """
        ])
        #expect(
            swept.run.status != 0,
            "an ambiguous nest was rewritten:\n\(swept.run.stdout)"
        )
        #expect(
            swept.run.stderr.contains("longer fence"),
            """
            the refusal does not say how to fix it:
            \(swept.run.stderr)
            """
        )
    }

    @Test("A longer code fence owns the fence inside it")
    func respectsCodeFenceLength() throws {
        // remark: no directive at all — the ````-block owns the
        // ```-run. A parser that toggles on any fence reads the
        // inner one as a CLOSE and then rewrites the example's
        // prose, which is the sharpest way this script can do
        // damage.
        let page = """
            ````md
            ```
            :::unreleased
            x
            :::
            ```
            ````
            """
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            """
            a nested code example was rewritten:
            \(swept.pages["a.md"] ?? "")
            """
        )
    }

    @Test("A closer shorter than the opener is content")
    func shortCloserIsNotAClose() throws {
        // remark: one directive containing `A`, `:::` and `B`.
        // Popping at the short run leaves an orphan `::::` line
        // in a released doc.
        let swept = try sweepFixtureCorpus([
            "a.md": "::::unreleased\nA\n:::\nB\n::::\n"
        ])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        let after = swept.pages["a.md"] ?? ""
        #expect(
            !after.contains("::::"),
            "an orphan outer fence was left behind:\n\(after)"
        )
        #expect(
            after.contains("A\n:::\nB"),
            "the block's own content changed:\n\(after)"
        )
    }

    @Test("A tilde-fenced example is an example too")
    func respectsTildeFences() throws {
        // remark: no directive — the `~~~` block owns it. Named
        // separately from the backtick case because the two are
        // separate alternatives in one regex, and dropping either
        // leaves the other's fixture green.
        let page = "~~~md\n:::unreleased\nexample\n:::\n~~~\n"
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            """
            a tilde-fenced example was rewritten:
            \(swept.pages["a.md"] ?? "")
            """
        )
    }

    @Test("A fence with an info string does not close a block")
    func infoStringIsNotAClosingFence() throws {
        // remark: one code node, no directive. CommonMark says a
        // CLOSING fence carries no info string, so reading the
        // inner ```js as a close hands the example's own prose to
        // the sweep to rewrite — the sharpest damage this script
        // can do.
        let page = "```\n```js\n:::unreleased\nx\n:::\n```\n"
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            """
            an info-string fence was read as a close:
            \(swept.pages["a.md"] ?? "")
            """
        )
    }

    @Test("Writing about the marker in prose is not using one")
    func leavesAnInlineMentionAlone() throws {
        // remark: no directive. This is the page that documents
        // the marker, so a refusal here would block the one doc
        // most likely to name it.
        let page = "See `:::unreleased` for unshipped behaviour.\n"
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            """
            an inline mention was treated as a marker:
            \(swept.pages["a.md"] ?? "")
            """
        )
    }

    @Test("A marker inside a blockquote or list is refused")
    func refusesAContainerNestedMarker() throws {
        // remark parses BOTH (`> :::unreleased` and a four-space
        // list continuation), so both render a badge — and this
        // parser reads no container prefixes, so it would retire
        // neither. Refusing is what stops that being silent.
        for page in [
            "> :::unreleased\n> x\n> :::\n",
            "-   item\n\n    :::unreleased\n    x\n    :::\n",
        ] {
            let swept = try sweepFixtureCorpus(["a.md": page])
            #expect(
                swept.run.status != 0,
                "a container-nested marker was accepted:\n\(page)"
            )
            #expect(
                swept.run.stderr.contains("top level"),
                """
                the refusal does not say what to do:
                \(swept.run.stderr)
                """
            )
        }
    }

    @Test("A directive nothing renders is refused")
    func refusesAnUnknownDirective() throws {
        // An unhandled container directive renders as a bare
        // <div> with no trace of itself, so a typo is silent on
        // the page as well as in the sweep. This refusal is what
        // the docstring above nominates as catching a rename of
        // the plugin's DIRECTIVE export.
        let swept = try sweepFixtureCorpus([
            "a.md": ":::unreleses\nx\n:::\n"
        ])
        #expect(
            swept.run.status != 0,
            "an unrenderable directive passed:\n\(swept.run.stdout)"
        )
        #expect(
            swept.run.stderr.contains("nothing renders"),
            """
            the refusal does not say why it refused:
            \(swept.run.stderr)
            """
        )
    }

    @Test("A Starlight aside on its own is left alone")
    func leavesAsidesAlone() throws {
        // The other side of that refusal: the four names
        // Starlight renders must pass untouched, or the gate
        // blocks legitimate prose.
        let page = ":::note\nAn aside.\n:::\n"
        let swept = try sweepFixtureCorpus(["a.md": page])
        #expect(swept.run.status == 0, "\(swept.run.stderr)")
        #expect(
            swept.pages["a.md"] == page,
            "an aside was rewritten:\n\(swept.pages["a.md"] ?? "")"
        )
    }
}
