import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The docs tools (#3213): `docs_search` ranks and lists,
/// `docs_get` returns a section word for word, and both answer
/// from the index this build ships, without the app.
@Suite("MCP docs tools (#3213)")
struct MCPDocsToolsTests {
    private static let fixture = DocsIndex(pages: [
        DocsIndex.Page(
            page: "guide",
            title: "Guide",
            description: "How it works.",
            sections: [
                section("guide", "Guide", 1, ["# Guide\n\nWelcome."]),
                section(
                    "gaps",
                    "Gaps",
                    2,
                    [
                        "## Gaps\n\nThe gap between windows.",
                        "More about the outer gap.",
                    ]
                ),
                section(
                    "set_gap",
                    "set_gap",
                    3,
                    ["### set_gap\n\n**Expects:** points."]
                ),
                section(
                    "borders",
                    "Borders",
                    2,
                    ["## Borders\n\nA border has a width."]
                ),
            ]
        ),
        DocsIndex.Page(
            page: "other",
            title: "Other",
            description: "The rest.",
            sections: [
                section("other", "Other", 1, ["# Other\n\nA gap note."])
            ]
        ),
    ])

    private static func section(
        _ anchor: String,
        _ heading: String,
        _ level: Int,
        _ parts: [String]
    ) -> DocsIndex.Section {
        DocsIndex.Section(
            anchor: anchor,
            heading: heading,
            level: level,
            parts: parts
        )
    }

    private static func call(
        _ name: String,
        _ arguments: [String: JSONValue],
        docs: DocsIndex? = fixture
    ) throws -> [String: JSONValue] {
        let app = MCPToolsTests.FakeApp()
        var tools = app.tools
        tools.docs = docs
        let result = try MCPToolsTests.call(tools, name, arguments)
        // Neither tool reaches the app.
        #expect(app.sent.isEmpty)
        return result
    }

    private static func structured(
        _ result: [String: JSONValue]
    ) -> [String: JSONValue] {
        guard case .object(let fields)? = result["structuredContent"]
        else { return [:] }
        return fields
    }

    private static func rows(
        _ result: [String: JSONValue],
        _ key: String
    ) -> [[String: JSONValue]] {
        guard case .array(let rows)? = structured(result)[key] else {
            return []
        }
        return rows.compactMap { row in
            if case .object(let fields) = row { return fields }
            return nil
        }
    }

    @Test("a heading match outranks a body match")
    func searchRanks() throws {
        let result = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("set_gap")]
        )
        let hits = Self.rows(result, "results")
        #expect(hits.first?["anchor"] == .string("set_gap"))
        #expect(hits.first?["page"] == .string("guide"))
        let plural = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("how do I make the borders thinner")]
        )
        #expect(
            Self.rows(plural, "results").first?["anchor"]
                == .string("borders")
        )
        let none = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("zeppelin")]
        )
        #expect(none["isError"] == .bool(false))
        #expect(Self.rows(none, "results").isEmpty)
    }

    @Test("section narrows to a page or to one section's subtree")
    func sectionScopes() throws {
        let page = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("gap"), "section": .string("other")]
        )
        #expect(
            Self.rows(page, "results").map { $0["page"] }
                == [.string("other")]
        )
        let subtree = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("width gap"), "section": .string("guide#gaps")]
        )
        let anchors = Self.rows(subtree, "results").map { $0["anchor"] }
        #expect(!anchors.isEmpty)
        #expect(!anchors.contains(.string("borders")))
        for bad in ["nowhere", "guide#nowhere"] {
            let refused = try Self.call(
                MCPTools.docsSearch,
                ["query": .string("gap"), "section": .string(bad)]
            )
            #expect(refused["isError"] == .bool(true), "\(bad)")
        }
    }

    @Test("limit caps the hits and refuses what it cannot mean")
    func limitBounds() throws {
        let one = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("gap"), "limit": .number(1)]
        )
        #expect(Self.rows(one, "results").count == 1)
        let all = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("gap"), "limit": .null]
        )
        #expect(Self.rows(all, "results").count > 1)
        for bad: JSONValue in [.number(0), .number(21), .string("3")] {
            let refused = try Self.call(
                MCPTools.docsSearch,
                ["query": .string("gap"), "limit": bad]
            )
            #expect(refused["isError"] == .bool(true), "\(bad)")
        }
    }

    @Test("an empty query lists the pages and the version")
    func emptyQueryLists() throws {
        for query: JSONValue? in [nil, .string(""), .string("  the ")] {
            var arguments: [String: JSONValue] = [:]
            if let query { arguments["query"] = query }
            let result = try Self.call(MCPTools.docsSearch, arguments)
            let fields = Self.structured(result)
            #expect(
                fields["version"]
                    == .string(KiwiDeskVersion.displayString)
            )
            let pages = Self.rows(result, "pages")
            #expect(
                pages.map { $0["page"] }
                    == [.string("guide"), .string("other")]
            )
            // Top sections only, until a page is named.
            guard case .array(let sections)? = pages[0]["sections"] else {
                Issue.record("no sections")
                continue
            }
            #expect(sections.count == 2)
        }
        let scoped = try Self.call(
            MCPTools.docsSearch,
            ["section": .string("guide")]
        )
        guard
            case .array(let all)? = Self.rows(scoped, "pages")
                .first?["sections"]
        else {
            Issue.record("no sections")
            return
        }
        #expect(all.count == 4)
    }

    @Test("docs_get returns the section's text word for word")
    func getReturnsTheText() throws {
        let result = try Self.call(
            MCPTools.docsGet,
            ["page": .string("guide.md"), "anchor": .string("gaps")]
        )
        let fields = Self.structured(result)
        #expect(
            fields["text"] == .string("## Gaps\n\nThe gap between windows.")
        )
        #expect(fields["parts"] == .number(2))
        #expect(
            Self.rows(result, "subsections").map { $0["anchor"] }
                == [.string("set_gap")]
        )
        let text = MCPToolsTests.text(result)
        #expect(text.hasPrefix("## Gaps\n\nThe gap between windows."))
        #expect(text.contains("Part 1 of 2"))
        let second = try Self.call(
            MCPTools.docsGet,
            [
                "page": .string("guide"), "anchor": .string("gaps"),
                "part": .number(2),
            ]
        )
        #expect(
            Self.structured(second)["text"]
                == .string("More about the outer gap.")
        )
        let opening = try Self.call(
            MCPTools.docsGet,
            ["page": .string("guide")]
        )
        #expect(Self.structured(opening)["anchor"] == .string("guide"))
        #expect(
            Self.rows(opening, "subsections").map { $0["anchor"] }
                == [.string("gaps"), .string("borders")]
        )
    }

    @Test("docs_get refuses what the index does not hold")
    func getRefuses() throws {
        let cases: [[String: JSONValue]] = [
            [:],
            ["page": .string("nowhere")],
            ["page": .string("guide"), "anchor": .string("nowhere")],
            [
                "page": .string("guide"), "anchor": .string("gaps"),
                "part": .number(3),
            ],
        ]
        for arguments in cases {
            let refused = try Self.call(MCPTools.docsGet, arguments)
            #expect(refused["isError"] == .bool(true), "\(arguments)")
        }
        let named = try Self.call(
            MCPTools.docsGet,
            ["page": .string("nowhere")]
        )
        #expect(MCPToolsTests.text(named).contains("guide, other"))
    }

    @Test("a build with no index says so")
    func missingIndex() throws {
        for name in [MCPTools.docsSearch, MCPTools.docsGet] {
            let result = try Self.call(
                name,
                ["page": .string("guide"), "query": .string("gap")],
                docs: nil
            )
            #expect(result["isError"] == .bool(true))
            #expect(MCPToolsTests.text(result) == MCPTools.docsMissing)
        }
    }

    @Test("both tools are read-only")
    func toolsAreReadOnly() throws {
        for tool in [MCPTools.docsSearchTool, MCPTools.docsGetTool] {
            guard case .object(let fields) = tool.definition,
                case .object(let notes)? = fields["annotations"]
            else {
                Issue.record("\(tool.name) has no annotations")
                continue
            }
            #expect(notes["readOnlyHint"] == .bool(true))
            #expect(notes["destructiveHint"] == .bool(false))
        }
    }
}
