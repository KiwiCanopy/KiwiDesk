import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The docs tools (#3213): `docs_search` ranks and lists,
/// `docs_get` returns a section word for word, and both answer
/// from the index this build ships, without the app.
@Suite("MCP docs tools (#3213)")
struct MCPDocsToolsTests {
    /// The Gaps section's first part: it mentions `set_gap` more
    /// often than that command's own section does.
    static let gapsOpening =
        "## Gaps\n\nThe gap between windows: set_gap, set_gap, set_gap."

    static let fixture = DocsIndex(pages: [
        DocsIndex.Page(
            page: "guide",
            title: "Guide",
            description: "How it works.",
            sections: [
                section(
                    "guide",
                    "Guide",
                    1,
                    ["# Guide\n\nWelcome. A border, a border, a border."]
                ),
                section(
                    "gaps",
                    "Gaps",
                    2,
                    [
                        gapsOpening,
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
                section("other", "Other", 1, ["# Other\n\nA gap note."]),
                section(
                    "app_ruleset_float",
                    "app_rule.set_float",
                    3,
                    [
                        "### app_rule.set_float\n\napp_rules, app_rules, "
                            + "app_rules, app_rules and app_rules."
                    ]
                ),
                section(
                    "app_rules",
                    "app_rules",
                    3,
                    ["### app_rules\n\nThe table."]
                ),
                section(
                    "kiwideskexec",
                    "`KiwiDesk.exec`",
                    3,
                    ["### `KiwiDesk.exec`\n\nRuns a program."]
                ),
            ]
        ),
    ])

    static func section(
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

    static func call(
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

    static func structured(
        _ result: [String: JSONValue]
    ) -> [String: JSONValue] {
        guard case .object(let fields)? = result["structuredContent"]
        else { return [:] }
        return fields
    }

    static func rows(
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
        // A name ending in s, and one spelled on its Lua table.
        for (query, anchor) in [
            ("app_rules", "app_rules"), ("exec", "kiwideskexec"),
        ] {
            let named = try Self.call(
                MCPTools.docsSearch,
                ["query": .string(query)]
            )
            #expect(
                Self.rows(named, "results").first?["anchor"]
                    == .string(anchor),
                "\(query)"
            )
        }
        // A later part has no heading line to skip.
        let later = try Self.call(
            MCPTools.docsSearch,
            ["query": .string("outer")]
        )
        #expect(
            Self.rows(later, "results").first?["snippet"]
                == .string("More about the outer gap.")
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
        let bad: [JSONValue] = [
            .number(0), .number(21), .number(2.5), .string("3"),
        ]
        for bad in bad {
            let refused = try Self.call(
                MCPTools.docsSearch,
                ["query": .string("gap"), "limit": bad]
            )
            #expect(refused["isError"] == .bool(true), "\(bad)")
        }
    }

    @Test("a query or section that is not text is refused")
    func wrongTypesRefuse() throws {
        for arguments: [String: JSONValue] in [
            ["query": .number(5)], ["section": .bool(true)],
        ] {
            let refused = try Self.call(MCPTools.docsSearch, arguments)
            #expect(refused["isError"] == .bool(true), "\(arguments)")
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
                    == .string(KiwiDeskVersion.semantic)
            )
            let pages = Self.rows(result, "pages")
            #expect(
                pages.map { $0["page"] }
                    == [.string("guide"), .string("other")]
            )
            // The title and top sections only, until a page is named.
            guard case .array(let sections)? = pages[0]["sections"] else {
                Issue.record("no sections")
                continue
            }
            #expect(sections.count == 3)
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

}
