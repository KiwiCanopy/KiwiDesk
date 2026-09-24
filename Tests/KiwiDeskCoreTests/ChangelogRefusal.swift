import Testing

/// The malformed release bodies `ChangelogParserTests` requires
/// `scripts/changelog-sync` to refuse, and the message each one
/// must produce.
///
/// A table rather than sixteen test functions, and its own file
/// rather than a nested type, for one reason: the suite is the
/// argument and this is the evidence, and the two grow at
/// different rates — every new refusal the parser learns adds a
/// row here and nothing there. Splitting before the file-size
/// ceiling rather than after is what `.claude/rules/tests.md`
/// asks for.
///
/// The `fragment` is as load-bearing as the exit code. A refusal
/// that does not say WHICH line is wrong sends a maintainer back
/// to re-read the whole body, which is the failure the parser was
/// built to avoid — it reports every problem at once precisely so
/// one round is enough.
struct ChangelogRefusal {
    let name: String
    let body: String
    let fragment: String
}

extension ChangelogRefusal {
    static let all: [ChangelogRefusal] = [
        ChangelogRefusal(
            name: "no curated block at all",
            body: "Just some prose, no heading.",
            fragment: "no `## Highlights` block"
        ),
        ChangelogRefusal(
            name: "the block is present but empty",
            body: "## Highlights",
            fragment: "present but empty"
        ),
        ChangelogRefusal(
            name: "no summary before the first section",
            body: """
                ## Highlights

                ### New

                - An entry.
                """,
            fragment: "no summary"
        ),
        ChangelogRefusal(
            name: "a section with nothing under it",
            body: """
                ## Highlights

                Summary.

                ### New

                ### Fixed

                - An entry.
                """,
            fragment: "is empty"
        ),
        ChangelogRefusal(
            name: "an entry with no text",
            body: """
                ## Highlights

                Summary.

                ### New

                -
                """,
            fragment: "bullet marker with no text"
        ),
        ChangelogRefusal(
            name: "an issue number in an entry",
            body: """
                ## Highlights

                Summary.

                ### New

                - The outline keeps up now (#618).
                """,
            fragment: "cites '#618'"
        ),
        ChangelogRefusal(
            name: "an issue number in the summary",
            body: """
                ## Highlights

                Fixes the crash from #873 at last.

                ### New

                - An entry.
                """,
            fragment: "the summary cites"
        ),
        ChangelogRefusal(
            name: "an issue number in a section title",
            body: """
                ## Highlights

                Summary.

                ### Fixed #873

                - An entry.
                """,
            fragment: "section title"
        ),
        ChangelogRefusal(
            name: "a PR link in an entry",
            body: """
                ## Highlights

                Summary.

                ### New

                - See github.com/KiwiCanopy/KiwiDesk/pull/880 for
                  the detail.
                """,
            fragment: "carry no issue or PR numbers"
        ),
        ChangelogRefusal(
            name: "a heading deeper than three",
            body: """
                ## Highlights

                Summary.

                ### New

                #### Deeper

                - An entry.
                """,
            fragment: "deeper than `###`"
        ),
        ChangelogRefusal(
            name: "a level-one heading inside the block",
            body: """
                ## Highlights

                Summary.
                # Stray

                ### New

                - An entry.
                """,
            fragment: "level-1 `#` heading"
        ),
        ChangelogRefusal(
            name: "a section heading with no title",
            body: """
                ## Highlights

                Summary.

                ###

                - An entry.
                """,
            fragment: "no title"
        ),
        ChangelogRefusal(
            name: "a bullet before the first section",
            body: """
                ## Highlights

                - A bullet where the summary belongs.

                ### New

                - An entry.
                """,
            fragment: "before the first `###`"
        ),
        ChangelogRefusal(
            name: "a nested list item",
            body: """
                ## Highlights

                Summary.

                ### New

                - Parent entry.
                  - a child
                """,
            fragment: "nested list item"
        ),
        ChangelogRefusal(
            name: "a second Highlights heading",
            body: """
                ## Highlights

                Summary.

                ### New

                - An entry.

                ## Highlights

                ### Fixed

                - Another.
                """,
            fragment: "a second `## Highlights` heading"
        ),
        ChangelogRefusal(
            name: "a code fence inside the block",
            body: """
                ## Highlights

                Summary.

                ### New

                - An entry.

                ```
                brew install kiwidesk
                ```
                """,
            fragment: "code fence inside the curated block"
        ),
    ]
}

extension ChangelogRefusal: CustomTestStringConvertible {
    var testDescription: String { name }
}
