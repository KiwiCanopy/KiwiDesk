import Foundation
import Testing

/// `scripts/changelog-sync`'s parser is the guard for the release
/// body (#873): the workflow refuses a body it cannot read rather
/// than publishing a half-rendered page, and
/// `.claude/rules/packaging-and-release.md` states that as an
/// obligation. A guard whose refusals are documented and untested
/// is the shape that ships inert, so each refusal below is a case
/// that must actually red.
///
/// Driven through `--body <file>`, which parses one body from
/// disk and touches neither the network nor `gh`. That mode
/// exists for this suite AND for a maintainer checking a draft —
/// a draft has no tag to fetch, so `--release` cannot see one.
///
/// The real script runs in place rather than from a repo-shaped
/// fixture: `--body` reads only the path it is handed, so nothing
/// about the tree it sits in changes what it decides.
@Suite("Changelog body parser (#873)")
struct ChangelogParserTests {
    private func script() -> URL {
        scriptFixtureRepoRoot()
            .appendingPathComponent("scripts")
            .appendingPathComponent("changelog-sync")
    }

    private func parse(_ body: String) throws -> ScriptRun {
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "changelog-body-\(UUID().uuidString).md"
            )
        try body.write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        return try runPythonScript(
            at: script(),
            arguments: ["--body", file.path]
        )
    }

    /// The shape every other case is a mutation of. Deliberately
    /// exercises the two legitimate entry forms at once: a
    /// bulleted section, and a section whose body is plain prose
    /// with no bullet (0.9.7's "Translations" and "Also").
    private static let valid = """
        ## Highlights

        One or two sentences about the release.

        ### Windows behave

        - **The focus outline keeps up.** It used to trail
          behind when windows moved quickly.
        - Scrolling stops at the edge of your screen.

        ### Translations

        Better translations across all ten languages.

        ## What's Changed
        * fix(bars): something reviewers say by @someone
        """

    @Test("the shipped form parses")
    func validBodyParses() throws {
        let run = try parse(Self.valid)
        #expect(run.status == 0)
        #expect(run.stdout.contains("2 section(s)"))
        #expect(run.stdout.contains("3 entr(ies)"))
    }

    /// The generated list below the block is not this page's to
    /// render, so the split must stop at the next `##` — if it
    /// did not, `* fix(bars): …` would arrive as an entry and the
    /// reviewer language the voice ruling excludes would be on
    /// the page.
    @Test("the generated list below the block is not read")
    func generatedListExcluded() throws {
        let run = try parse(Self.valid)
        #expect(!run.stdout.contains("fix(bars)"))
    }

    /// Continuation lines are joined into one entry rather than
    /// becoming two — the wrapped bullet above is one sentence.
    @Test("a wrapped entry stays one entry")
    func wrappedEntryJoins() throws {
        let run = try parse(Self.valid)
        #expect(run.stdout.contains("Windows behave (2)"))
    }

    // MARK: - Refusals

    @Test(
        "each malformed body is refused, and says why",
        arguments: ChangelogRefusal.all
    )
    func malformedBodyRefused(_ refusal: ChangelogRefusal) throws {
        let run = try parse(refusal.body)
        #expect(
            run.status != 0,
            "\(refusal.name): accepted a body that must refuse"
        )
        #expect(
            run.stderr.contains(refusal.fragment),
            """
            \(refusal.name): refused without naming the problem.
            wanted a message containing \(refusal.fragment)
            got:
            \(run.stderr)
            """
        )
    }

    // MARK: - What must NOT be refused

    /// A guard that refuses legitimate bodies gets switched off.
    /// `#1E1E1E` is the case that motivated anchoring the issue
    /// pattern on both sides — an unanchored `#\\d+` reads a hex
    /// colour as issue 1.
    @Test(
        "a legitimate body is not refused",
        arguments: [
            (
                "a hex colour is not an issue number",
                "- The ring is now #1E1E1E by default."
            ),
            (
                "a heading anchor is not an issue number",
                "- Jump straight to [the layouts](#layouts)."
            ),
            (
                "an asterisk bullet is a bullet",
                "* An entry written with a star."
            ),
        ]
    )
    func legitimateBodyAccepted(
        _ testCase: (name: String, entry: String)
    ) throws {
        let body = """
            ## Highlights

            Summary.

            ### Thing

            \(testCase.entry)
            """
        let run = try parse(body)
        #expect(
            run.status == 0,
            """
            \(testCase.name): refused a legitimate body.
            \(run.stderr)
            """
        )
    }

    /// The one refusal that is a judgement call rather than a
    /// defect, pinned so switching it is a deliberate edit: an
    /// anchored `#\\d+` still reads "your #1 request" as issue 1.
    /// Accepted, because the message names the fix and rephrasing
    /// is cheap, while letting a real issue number through is the
    /// failure the guard exists to stop.
    @Test("a bare ordinal is refused, and that is the trade")
    func bareOrdinalRefused() throws {
        let run = try parse(
            """
            ## Highlights

            Summary.

            ### Thing

            - Your #1 request, shipped.
            """
        )
        #expect(run.status != 0)
        #expect(run.stderr.contains("cites '#1'"))
    }
}
