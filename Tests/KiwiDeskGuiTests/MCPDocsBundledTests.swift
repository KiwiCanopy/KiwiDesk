import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The docs this build ships and the links into them (#3213):
/// the bundled index loads, a command's `docs` field names a
/// section it holds, and those are the anchors
/// `docs/commands.md` links.
@Suite("MCP bundled docs (#3213)")
struct MCPDocsBundledTests {
    private static func index() throws -> DocsIndex {
        try #require(DocsIndex.bundled, "the docs index did not load")
    }

    /// Actions a key can run: the rows `docs/commands.md` lists.
    private static var bindable: [APIEntry] {
        APIReference.groups(of: .action).flatMap(\.entries)
            .filter { $0.channel != .cli }
    }

    @Test("the bundled index holds the user-facing pages")
    func indexLoads() throws {
        let index = try Self.index()
        let pages = Set(index.pages.map(\.page))
        for page in [
            "lua-reference", "user-guide", "spaces-and-desktops", "cli",
            "commands", "accepted-limitations", "recipes/index",
        ] {
            #expect(pages.contains(page), "\(page)")
        }
        #expect(!pages.contains("design-decisions"))
        for page in index.pages {
            #expect(!page.sections.isEmpty, "\(page.page)")
            #expect(page.sections.allSatisfy { !$0.parts.isEmpty })
            let anchors = page.sections.map(\.anchor)
            #expect(Set(anchors).count == anchors.count, "\(page.page)")
        }
    }

    @Test("every action's docs link names a section the build ships")
    func actionLinksResolve() throws {
        let index = try Self.index()
        let links = index.commandLinks
        #expect(Self.bindable.count > 50)
        for entry in Self.bindable {
            let name = entry.qualifiedName
            let link = try #require(links[name], "\(name) has no docs")
            // Through the door an AI app takes with help's answer.
            let read = try MCPToolsTests.call(
                MCPToolsTests.FakeApp().tools,
                MCPTools.docsGet,
                ["page": .string(link.page), "anchor": .string(link.anchor)]
            )
            #expect(read["isError"] == .bool(false), "\(name)")
        }
    }

    @Test("a command two headings name links to the first")
    func firstHeadingWins() {
        func section(_ anchor: String, _ level: Int) -> DocsIndex.Section {
            DocsIndex.Section(
                anchor: anchor,
                heading: "twice",
                level: level,
                parts: ["### twice"]
            )
        }
        let index = DocsIndex(pages: [
            DocsIndex.Page(
                page: DocsIndex.commandPage,
                title: "Lua",
                description: "",
                sections: [
                    section("group", 2), section("twice", 3),
                    section("twice-1", 3),
                ]
            )
        ])
        #expect(
            index.commandLinks
                == [
                    "twice": DocsIndex.Link(
                        page: DocsIndex.commandPage,
                        anchor: "twice"
                    )
                ]
        )
    }

    @Test("the links are the ones the actions page carries")
    func linksMatchTheActionsPage() throws {
        let index = try Self.index()
        let page = try #require(index.page(named: "commands"))
        let text = page.sections.flatMap(\.parts).joined(separator: "\n")
        let row = try Regex(
            #"\[`([^`]+)`\]\(lua-reference\.md#([^)]+)\)"#
        )
        var linked: [String: String] = [:]
        for match in text.matches(of: row) {
            guard let name = match.output[1].substring,
                let anchor = match.output[2].substring
            else { continue }
            linked[String(name)] = String(anchor)
        }
        #expect(linked.count == Self.bindable.count)
        let links = index.commandLinks
        for (name, anchor) in linked {
            #expect(
                links[name]
                    == DocsIndex.Link(page: "lua-reference", anchor: anchor),
                "\(name)"
            )
        }
    }

    @Test("help and list_commands carry docs and lua")
    func helpCarriesTheLink() throws {
        let tools = MCPToolsTests.FakeApp().tools
        let help = try MCPToolsTests.call(
            tools,
            MCPTools.help,
            ["name": .string("focus")]
        )
        guard case .object(let fields)? = help["structuredContent"] else {
            Issue.record("help answered no structure")
            return
        }
        #expect(
            fields["docs"]
                == .object([
                    "page": .string("lua-reference"),
                    "anchor": .string("focus"),
                ])
        )
        #expect(fields["lua"] == .string("KiwiDesk.focus(direction)"))
        #expect(fields["arguments"] != nil)
        #expect(MCPToolsTests.text(help).contains("\"lua\""))

        let listing = try MCPToolsTests.call(tools, MCPTools.listCommands)
        guard case .object(let body)? = listing["structuredContent"],
            case .array(let rows)? = body["commands"]
        else {
            Issue.record("list_commands answered no rows")
            return
        }
        let byName = Dictionary(
            rows.compactMap { row -> (String, [String: JSONValue])? in
                guard case .object(let fields) = row,
                    let name = fields["name"]?.stringValue
                else { return nil }
                return (name, fields)
            },
            uniquingKeysWith: { first, _ in first }
        )
        let links = try Self.index().commandLinks
        for entry in Self.bindable where MCPTools.isRunnable(entry) {
            let row = try #require(byName[entry.qualifiedName])
            let link = try #require(links[entry.qualifiedName])
            #expect(
                row["docs"]
                    == .object([
                        "page": .string(link.page),
                        "anchor": .string(link.anchor),
                    ]),
                "\(entry.qualifiedName)"
            )
            #expect(row["lua"] != nil, "\(entry.qualifiedName)")
        }
        // A command with no Lua call and no section carries neither.
        let subscribe = APIReference.socketOnlyCommand
        #expect(links[subscribe] == nil)
        let bare = try MCPToolsTests.call(
            tools,
            MCPTools.help,
            ["name": .string(subscribe)]
        )
        guard case .object(let none)? = bare["structuredContent"] else {
            Issue.record("help answered no structure")
            return
        }
        #expect(none["docs"] == nil)
        #expect(none["lua"] == nil)
        #expect(none["arguments"] != nil)
    }

    @Test("help links into the docs its own server reads")
    func linksFollowTheServersDocs() throws {
        var tools = MCPToolsTests.FakeApp().tools
        tools.docs = nil
        let help = try MCPToolsTests.call(
            tools,
            MCPTools.help,
            ["name": .string("focus")]
        )
        guard case .object(let fields)? = help["structuredContent"] else {
            Issue.record("help answered no structure")
            return
        }
        #expect(fields["docs"] == nil)
        #expect(fields["lua"] == .string("KiwiDesk.focus(direction)"))
    }

    @Test("a linked section reads back through docs_get")
    func linkedSectionReads() throws {
        let tools = MCPToolsTests.FakeApp().tools
        let result = try MCPToolsTests.call(
            tools,
            MCPTools.docsGet,
            [
                "page": .string("lua-reference"),
                "anchor": .string("set_gap_global"),
            ]
        )
        #expect(result["isError"] == .bool(false))
        let text = MCPToolsTests.text(result)
        #expect(text.hasPrefix("### set_gap_global"))
        #expect(text.contains("**Expects:**"))
        let found = try MCPToolsTests.call(
            tools,
            MCPTools.docsSearch,
            ["query": .string("border width")]
        )
        #expect(MCPToolsTests.text(found).contains("border.set_width"))
    }
}
