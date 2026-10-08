/// The spotlight bodies `changelog-sync` must refuse (#2038), as
/// rows of `ChangelogParserTests` ▸ `malformedBodyRefused`. Every
/// body is a draft (no tag), so the census clause runs against
/// this tree's own `SettingKey` census.
extension ChangelogRefusal {
    private static func body(
        summary: String = "KiwiDesk 2.2 is about speed.",
        spotlight: String,
        after: String = ""
    ) -> String {
        """
        ## Highlights

        \(summary)

        ### Spotlight

        \(spotlight)
        \(after)
        ### New

        - A thing.
        """
    }

    static let spotlight: [ChangelogRefusal] = [
        ChangelogRefusal(
            name: "more than four spotlight rows",
            body: body(
                spotlight: """
                    - **One** — a line.
                    - **Two** — a line.
                    - **Three** — a line.
                    - **Four** — a line.
                    - **Five** — a line.
                    """
            ),
            fragment: "5 spotlight rows. At most 4"
        ),
        ChangelogRefusal(
            name: "a spotlight row without a title",
            body: body(spotlight: "- Just a line, no title."),
            fragment: "has no title"
        ),
        ChangelogRefusal(
            name: "a spotlight row without a line",
            body: body(spotlight: "- **Only a title**"),
            fragment: "has no line after its title"
        ),
        ChangelogRefusal(
            name: "an issue number in a spotlight row",
            body: body(spotlight: "- **Faster** — as asked in #1508."),
            fragment: "cites '#1508'"
        ),
        ChangelogRefusal(
            name: "a setting the census does not know",
            body: body(
                spotlight: "- **Faster** — a line. {setting:no.such.key}"
            ),
            fragment: "cannot land on"
        ),
        // A real census id "Show me" can never land on: a
        // per-Space instance is a link, never a search row.
        ChangelogRefusal(
            name: "a census id no search row lands on",
            body: body(
                spotlight: "- **Gaps** — a line. "
                    + "{setting:settings.gapsOverride[space]}"
            ),
            fragment: "cannot land on"
        ),
        ChangelogRefusal(
            name: "an unknown token in a spotlight row",
            body: body(spotlight: "- **Faster** — a line. {colour:red}"),
            fragment: "unknown token"
        ),
        ChangelogRefusal(
            name: "a symbol that is no SF Symbol name",
            body: body(
                spotlight: "- **Faster** — a line. {symbol:Bolt Fill}"
            ),
            fragment: "is not an SF Symbol name"
        ),
        ChangelogRefusal(
            name: "two sentences of prose beside the rows",
            body: body(
                summary: "KiwiDesk 2.2 is fast. It is polished too.",
                spotlight: "- **Faster** — a line."
            ),
            fragment: "prose beside spotlight rows"
        ),
        ChangelogRefusal(
            name: "an intro sentence past the length cap",
            body: body(
                summary: "KiwiDesk 2.2 "
                    + String(repeating: "is very fast and ", count: 12)
                    + "polished.",
                spotlight: "- **Faster** — a line."
            ),
            fragment: "prose beside spotlight rows"
        ),
        ChangelogRefusal(
            name: "a spotlight that is not the first section",
            body: """
                ## Highlights

                KiwiDesk 2.2 is about speed.

                ### New

                - A thing.

                ### Spotlight

                - **Faster** — a line.
                """,
            fragment: "must be the first section"
        ),
        ChangelogRefusal(
            name: "an empty spotlight",
            body: body(spotlight: ""),
            fragment: "`### Spotlight` is empty"
        ),
    ]
}
