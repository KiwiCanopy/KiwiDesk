import Foundation
import Testing

/// The Discord post's shape beside a Spotlight and its counted
/// close: a block with Spotlight rows posts the rows as
/// `**Title** — line`, without the app's `{setting:}` and
/// `{symbol:}` tokens and without its sections, and every post
/// closes on a sentence counting the changes in words. Split from
/// `DiscordAnnounceTests` at the file ceiling; driven through
/// `--dry-run` over a releases fixture, so nothing touches the
/// network.
@Suite("Discord release announcement: Spotlight and counts")
struct DiscordAnnounceSpotlightTests {
    private static let tag = "v9999.4.0"
    private static let url = "https://example.invalid/release"
    private static let notes = "[release notes](\(url))"

    private static let rowFast =
        "- **Fast switches** — Switching keeps up. "
        + "{symbol:gauge.with.dots.needle.67percent}"
    private static let rowHover =
        "- **Windows on hover** — Rest on an app to list its windows. "
        + "{setting:settings.animations.onSpaceChange} "
        + "{symbol:list.bullet.rectangle}"

    private func description(of body: String) throws -> String {
        let release: [String: Any] = [
            "tag_name": Self.tag,
            "published_at": "2026-10-09T10:00:00Z",
            "draft": false,
            "html_url": Self.url,
            "body": body,
            "assets": [],
        ]
        let file = FileManager.default.temporaryDirectory
            .appendingPathComponent(
                "discord-spotlight-\(UUID().uuidString).json"
            )
        try JSONSerialization.data(withJSONObject: [release])
            .write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }
        let result = try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts")
                .appendingPathComponent("discord-announce"),
            arguments: [
                "--release", Self.tag, "--releases", file.path,
                "--dry-run",
            ]
        )
        try #require(result.status == 0, "\(result.stderr)")
        let object =
            try JSONSerialization
            .jsonObject(with: Data(result.stdout.utf8)) as? [String: Any]
        let embeds = object?["embeds"] as? [[String: Any]]
        return try #require(embeds?.first?["description"] as? String)
    }

    @Test("a Spotlight release posts its rows, not its sections")
    func spotlightPostsRows() throws {
        let text = try description(
            of: """
                ## Highlights

                KiwiDesk 9999.4.0 is about one thing.

                ### Spotlight

                \(Self.rowFast)
                \(Self.rowHover)

                ### New

                - **Windows on hover** in the bars.

                ### Fixed

                - **A fix.**
                - **Another fix.**
                """
        )
        let paragraphs = text.components(separatedBy: "\n\n")
        #expect(paragraphs.first == "KiwiDesk 9999.4.0 is about one thing.")
        #expect(
            paragraphs.dropFirst().first
                == "**Fast switches** — Switching keeps up.\n"
                + "**Windows on hover** — Rest on an app to list its "
                + "windows."
        )
        #expect(!text.contains("{"))
        #expect(!text.contains("**New"))
        #expect(!text.contains("- **A fix.**"))
        #expect(
            text.contains(
                "This release brings 1 addition and 2 fixes — all of "
                    + "them in the \(Self.notes)."
            )
        )
    }

    @Test(
        "the count reads as a sentence",
        arguments: [
            ("### Fixed\n\n- **A fix.**", "1 fix — see the"),
            (
                "### Improved\n\n- **One.**\n- **Two.**\n\n"
                    + "### Lua & CLI\n\n- **Three.**",
                "2 improvements and 1 Lua & CLI change — all of them in the"
            ),
        ]
    )
    func countReadsAsASentence(_ sections: String, _ phrase: String) throws {
        let text = try description(
            of: "## Highlights\n\nA summary.\n\n\(sections)\n"
        )
        #expect(
            text.contains("This release brings \(phrase) \(Self.notes).")
        )
    }
}
