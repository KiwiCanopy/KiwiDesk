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
    private static let url = "https://example.invalid/release"
    private static let notes = "[release notes](\(url))"
    private static let updateTail = "in the footer of Settings Home."

    private static let rowFast =
        "- **Fast switches** — Switching keeps up. "
        + "{symbol:gauge.with.dots.needle.67percent}"
    private static let rowHover =
        "- **Windows on hover** — Rest on an app to list its windows. "
        + "{setting:settings.animations.onSpaceChange} "
        + "{symbol:list.bullet.rectangle}"

    private func description(
        of body: String,
        tag: String = "v9999.4.0"
    ) throws -> String {
        let release: [String: Any] = [
            "tag_name": tag,
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
                "--release", tag, "--releases", file.path,
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
        #expect(!text.contains("**New"))
        #expect(!text.contains("- **A fix.**"))
        #expect(text.hasSuffix(Self.updateTail))
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
                "### New\n\n- **A.**\n\n### Improved\n\n- **B.**\n\n"
                    + "### Fixed\n\n- **C.**",
                "1 addition, 1 improvement and 1 fix — all of them in the"
            ),
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

    /// Rows have no length cap, so a long Spotlight is clipped to
    /// fit beside the close rather than crowding the head forever.
    @Test("a long Spotlight still posts within the embed limit")
    func longSpotlightFits() throws {
        let line = String(repeating: "word ", count: 300) + "end."
        let rows = (1...4)
            .map { "- **Row \($0)** — \(line) {symbol:keyboard}" }
            .joined(separator: "\n")
        let text = try description(
            of: "## Highlights\n\nA summary.\n\n### Spotlight\n\n"
                + "\(rows)\n\n### Fixed\n\n- **A fix.**\n"
        )
        #expect(text.count <= 4096)
        #expect(text.hasPrefix("A summary."))
        #expect(text.contains("This release brings 1 fix"))
    }

    /// A release from before the section types counts nothing,
    /// and says where everything is instead.
    @Test("an untyped release points at the notes")
    func untypedReleasePoints() throws {
        let text = try description(
            of: "## Highlights\n\nA summary.\n\n### New\n\n- **A.**\n",
            tag: "v1.9.0"
        )
        #expect(
            text.contains("Everything that changed is in the \(Self.notes).")
        )
    }

    /// Every section type the parser knows has its own nouns, so a
    /// new type is named rather than counted as plain changes.
    @Test("every section type has its nouns")
    func nounsCoverEverySectionType() throws {
        let root = scriptFixtureRepoRoot().path
        let code = """
            import importlib.machinery, importlib.util, sys
            def load(name):
                path = sys.argv[1] + "/scripts/" + name
                loader = importlib.machinery.SourceFileLoader(name, path)
                spec = importlib.util.spec_from_loader(name, loader)
                module = importlib.util.module_from_spec(spec)
                loader.exec_module(module)
                return module
            types = {t for _, t in load("changelog-sync").SECTION_TYPES}
            nouns = set(load("discord-announce").NOUNS)
            print(sorted(types), sorted(nouns))
            sys.exit(0 if types and types == nouns else 1)
            """
        let result = try spawn("/usr/bin/env", ["python3", "-c", code, root])
        #expect(result.status == 0, "\(result.stdout)\(result.stderr)")
    }
}
