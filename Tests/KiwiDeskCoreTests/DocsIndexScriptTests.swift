import Foundation
import Testing

@testable import KiwiDeskCore

/// `scripts/docs-index` writes the docs `kiwidesk mcp` serves
/// (#3213). These cases run the real script over throwaway trees:
/// what it indexes, what it does with a marker and a figure, where
/// it cuts a long section, and what it refuses.
@Suite("docs index script (#3213)")
struct DocsIndexScriptTests {
    /// The pages the script requires, as stubs a case overrides.
    private static let required = [
        "lua-reference.md", "user-guide.md", "spaces-and-desktops.md",
        "cli.md", "commands.md", "accepted-limitations.md",
        "recipes/index.md",
    ]

    private struct Indexed {
        let run: ScriptRun
        /// Page name → its sections, as the script wrote them.
        let pages: [String: [[String: Any]]]
        let out: URL
    }

    private static func index(
        _ pages: [String: String],
        omitting omitted: Set<String> = []
    ) throws -> Indexed {
        let root =
            testTemporaryDirectory
            .appendingPathComponent("docs-index-\(UUID().uuidString)")
        let docs = root.appendingPathComponent("docs")
        var corpus: [String: String] = [:]
        for name in required where !omitted.contains(name) {
            corpus[name] = "# Stub\n\nBody.\n"
        }
        corpus.merge(pages) { _, given in given }
        for (name, body) in corpus {
            let page = docs.appendingPathComponent(name)
            try FileManager.default.createDirectory(
                at: page.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try body.write(to: page, atomically: true, encoding: .utf8)
        }
        let out = root.appendingPathComponent("index.json")
        let run = try runPythonScript(
            at: scriptFixtureRepoRoot()
                .appendingPathComponent("scripts/docs-index"),
            arguments: ["--docs", docs.path, "--out", out.path]
        )
        var read: [String: [[String: Any]]] = [:]
        if let data = try? Data(contentsOf: out),
            let object = try JSONSerialization.jsonObject(with: data)
                as? [String: Any],
            let listed = object["pages"] as? [[String: Any]]
        {
            for page in listed {
                guard let name = page["page"] as? String else { continue }
                read[name] = page["sections"] as? [[String: Any]] ?? []
            }
        }
        return Indexed(run: run, pages: read, out: out)
    }

    private static func parts(_ section: [String: Any]) -> [String] {
        section["parts"] as? [String] ?? []
    }

    @Test("a marker's fences go and its text stays")
    func markerIsStripped() throws {
        let indexed = try Self.index([
            "cli.md": """
            ---
            title: CLI
            description: Commands.
            ---

            # CLI

            :::unreleased
            The new verb exists.
            :::

            ```md
            :::unreleased
            An example.
            :::
            ```
            """
        ])
        #expect(indexed.run.status == 0, "\(indexed.run.stderr)")
        let sections = try #require(indexed.pages["cli"])
        let text = Self.parts(try #require(sections.first))
            .joined(separator: "\n")
        #expect(text.contains("The new verb exists."))
        // The fenced example is prose about the marker and stays.
        #expect(text.components(separatedBy: ":::unreleased").count == 2)
        #expect(!text.contains("title: CLI"))
    }

    @Test("headings become sections with the site's anchors")
    func headingsAreSections() throws {
        let indexed = try Self.index([
            "user-guide.md": """
            # Guide

            ## Examples

            One.

            ```sh
            # not a heading
            ```

            ### `KiwiDesk.exec`

            ## Examples

            Two.
            """
        ])
        #expect(indexed.run.status == 0, "\(indexed.run.stderr)")
        let sections = try #require(indexed.pages["user-guide"])
        #expect(
            sections.compactMap { $0["anchor"] as? String }
                == ["guide", "examples", "kiwideskexec", "examples-1"]
        )
        #expect(sections.compactMap { $0["level"] as? Int } == [1, 2, 3, 2])
        let first = Self.parts(sections[1]).joined()
        #expect(first.contains("# not a heading"))
    }

    @Test("a folded description is kept whole; a table keeps its head")
    func frontmatterAndTables() throws {
        let cell = String(repeating: "word ", count: 500)
        let rows = (1...6).map { "| row \($0) | \(cell) |" }
        let page =
            ([
                "---", "title: CLI", "description: Every command, the",
                "  event stream.", "---", "", "# CLI", "", "## C#", "",
                "| Name | Does |", "|---|---|",
            ] + rows).joined(separator: "\n") + "\n"
        let indexed = try Self.index(["cli.md": page])
        #expect(indexed.run.status == 0, "\(indexed.run.stderr)")
        let data = try Data(contentsOf: indexed.out)
        let object = try #require(
            try JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        let pages = try #require(object["pages"] as? [[String: Any]])
        let cli = try #require(pages.first { $0["page"] as? String == "cli" })
        #expect(
            cli["description"] as? String
                == "Every command, the event stream."
        )
        let sections = try #require(indexed.pages["cli"])
        #expect(sections.last?["heading"] as? String == "C#")
        let parts = Self.parts(try #require(sections.last))
        #expect(parts.count > 2)
        #expect(parts[0].contains("| Name | Does |\n|---|---|\n| row 1 |"))
        #expect(parts.dropFirst().allSatisfy { $0.hasPrefix("| row") })
    }

    @Test("a figure is indexed as its label")
    func figureBecomesItsLabel() throws {
        let svg =
            "<svg viewBox=\"0 0 1 1\" role=\"img\" "
            + "aria-label=\"Two windows side by side\"><rect/></svg>"
        let indexed = try Self.index(["cli.md": "# CLI\n\n\(svg)\n"])
        #expect(indexed.run.status == 0, "\(indexed.run.stderr)")
        let text = Self.parts(try #require(indexed.pages["cli"]?.first))
            .joined()
        #expect(text.contains("[Figure: Two windows side by side]"))
        #expect(!text.contains("<svg"))
    }

    @Test("a long section is cut where a block ends, losing no line")
    func longSectionSplits() throws {
        let paragraph = String(repeating: "word ", count: 300)
        let code =
            "```\n"
            + Array(repeating: "line of code", count: 400)
            .joined(separator: "\n\n") + "\n```"
        let rows = (1...40).map { "| row \($0) | \(paragraph) |" }
        let body =
            (["# Long", "", paragraph, "", code, ""] + rows)
            .joined(separator: "\n")
        let indexed = try Self.index(["cli.md": body + "\n"])
        #expect(indexed.run.status == 0, "\(indexed.run.stderr)")
        let parts = Self.parts(try #require(indexed.pages["cli"]?.first))
        #expect(parts.count > 3)
        // A cut would fall inside the code block; it stays whole.
        let holders = parts.filter { $0.contains("line of code") }
        #expect(holders.count == 1)
        let kept = parts.joined(separator: "\n")
            .split(separator: "\n").filter { !$0.isEmpty }
        let given = body.split(separator: "\n").filter { !$0.isEmpty }
        #expect(kept == given)
        #expect(parts.dropFirst(2).allSatisfy { $0.hasPrefix("| row") })
    }

    @Test("a corpus it cannot index is refused, naming the page")
    func refusals() throws {
        let missing = try Self.index([:], omitting: ["cli.md"])
        #expect(missing.run.status != 0)
        #expect(missing.run.stderr.contains("cli.md"))
        let unlabelled = try Self.index([
            "cli.md": "# CLI\n\n<svg viewBox=\"0 0 1 1\"></svg>\n"
        ])
        #expect(unlabelled.run.status != 0)
        #expect(unlabelled.run.stderr.contains("cli.md"))
        let headless = try Self.index(["cli.md": "Loose text.\n\n# CLI\n"])
        #expect(headless.run.status != 0)
        let unclosed = try Self.index([
            "cli.md": "# CLI\n\n:::unreleased\nNever closed.\n"
        ])
        #expect(unclosed.run.status != 0)
        #expect(!FileManager.default.fileExists(atPath: unclosed.out.path))
    }

    @Test("--check reds on a stale index and writes nothing")
    func checkCatchesDrift() throws {
        let indexed = try Self.index(["cli.md": "# CLI\n\nOne.\n"])
        let script = scriptFixtureRepoRoot()
            .appendingPathComponent("scripts/docs-index")
        let docs = indexed.out.deletingLastPathComponent()
            .appendingPathComponent("docs")
        let arguments = [
            "--check", "--docs", docs.path, "--out", indexed.out.path,
        ]
        #expect(
            try runPythonScript(at: script, arguments: arguments)
                .status == 0
        )
        try "# CLI\n\nTwo.\n".write(
            to: docs.appendingPathComponent("cli.md"),
            atomically: true,
            encoding: .utf8
        )
        let before = try Data(contentsOf: indexed.out)
        let stale = try runPythonScript(at: script, arguments: arguments)
        #expect(stale.status == 1)
        #expect(stale.stderr.contains("scripts/docs-index"))
        #expect(try Data(contentsOf: indexed.out) == before)
    }
}
