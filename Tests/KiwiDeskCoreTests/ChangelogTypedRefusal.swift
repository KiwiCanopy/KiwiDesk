import Testing

/// The typed grammar's refusals (#1542): from 2.0.0 a release
/// body's sections are exactly New, Improved, Fixed, Lua & CLI,
/// in that order, and the summary may close in one Before you
/// update paragraph. Beside `ChangelogRefusal.all` rather than in
/// it, for the file-size ceiling.
extension ChangelogRefusal {
    static let typed: [ChangelogRefusal] = [
        ChangelogRefusal(
            name: "a section title that is not a type",
            body: """
                ## Highlights

                Summary.

                ### Fixes

                - An entry.
                """,
            fragment: "is not a type"
        ),
        ChangelogRefusal(
            name: "a type used twice",
            body: """
                ## Highlights

                Summary.

                ### New

                - One.

                ### New

                - Two.
                """,
            fragment: "appears 2 times"
        ),
        ChangelogRefusal(
            name: "the types out of order",
            body: """
                ## Highlights

                Summary.

                ### Fixed

                - One.

                ### New

                - Two.
                """,
            fragment: "out of order"
        ),
        ChangelogRefusal(
            name: "prose under a typed section",
            body: """
                ## Highlights

                Summary.

                ### Improved

                Better translations everywhere.
                """,
            fragment: "prose under `### Improved`"
        ),
        ChangelogRefusal(
            name: "Before you update not last",
            body: """
                ## Highlights

                **Before you update:** something breaks.

                Summary after it.

                ### New

                - One.
                """,
            fragment: "is not the last paragraph"
        ),
        ChangelogRefusal(
            name: "two Before you update paragraphs",
            body: """
                ## Highlights

                Summary.

                **Before you update:** one thing.

                **Before you update:** another.

                ### New

                - One.
                """,
            fragment: "2 `**Before you update:**` paragraphs"
        ),
        ChangelogRefusal(
            name: "Before you update inside a paragraph",
            body: """
                ## Highlights

                Summary. **Before you update:** mid-sentence.

                ### New

                - One.
                """,
            fragment: "must open its own paragraph"
        ),
        ChangelogRefusal(
            name: "Before you update with no text",
            body: """
                ## Highlights

                Summary.

                **Before you update:**

                ### New

                - One.
                """,
            fragment: "with nothing after it"
        ),
        ChangelogRefusal(
            name: "an issue number in Before you update",
            body: """
                ## Highlights

                Summary.

                **Before you update:** see #1517.

                ### New

                - One.
                """,
            fragment: "the Before you update paragraph cites"
        ),
    ]
}
