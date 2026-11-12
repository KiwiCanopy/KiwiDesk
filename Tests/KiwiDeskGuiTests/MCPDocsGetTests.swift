import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `docs_get` and the docs tools' edges (#3213): a section's text
/// word for word, what the index does not hold, and a build
/// without one. The fixture is `MCPDocsToolsTests`'.
@Suite("MCP docs_get (#3213)")
struct MCPDocsGetTests {
    @Test("docs_get returns the section's text word for word")
    func getReturnsTheText() throws {
        let result = try MCPDocsToolsTests.call(
            MCPTools.docsGet,
            ["page": .string("guide.md"), "anchor": .string("gaps")]
        )
        let fields = MCPDocsToolsTests.structured(result)
        #expect(
            fields["text"]
                == .string(MCPDocsToolsTests.gapsOpening)
        )
        #expect(fields["parts"] == .number(2))
        #expect(
            MCPDocsToolsTests.rows(result, "subsections").map { $0["anchor"] }
                == [.string("set_gap")]
        )
        let text = MCPToolsTests.text(result)
        #expect(
            text.hasPrefix(MCPDocsToolsTests.gapsOpening)
        )
        #expect(text.contains("Part 1 of 2"))
        let second = try MCPDocsToolsTests.call(
            MCPTools.docsGet,
            [
                "page": .string("guide"), "anchor": .string("gaps"),
                "part": .number(2),
            ]
        )
        #expect(
            MCPDocsToolsTests.structured(second)["text"]
                == .string("More about the outer gap.")
        )
        let opening = try MCPDocsToolsTests.call(
            MCPTools.docsGet,
            ["page": .string("guide")]
        )
        #expect(
            MCPDocsToolsTests.structured(opening)["anchor"] == .string("guide")
        )
        #expect(
            MCPDocsToolsTests.rows(opening, "subsections").map { $0["anchor"] }
                == [.string("gaps"), .string("borders")]
        )
    }

    @Test("docs_get refuses what the index does not hold")
    func getRefuses() throws {
        let cases: [[String: JSONValue]] = [
            [:],
            ["page": .number(1)],
            [
                "page": .string("guide"), "anchor": .string("gaps"),
                "part": .number(1.5),
            ],
            ["page": .string("nowhere")],
            ["page": .string("guide"), "anchor": .string("nowhere")],
            [
                "page": .string("guide"), "anchor": .string("gaps"),
                "part": .number(3),
            ],
        ]
        for arguments in cases {
            let refused = try MCPDocsToolsTests.call(
                MCPTools.docsGet,
                arguments
            )
            #expect(refused["isError"] == .bool(true), "\(arguments)")
        }
        let named = try MCPDocsToolsTests.call(
            MCPTools.docsGet,
            ["page": .string("nowhere")]
        )
        #expect(MCPToolsTests.text(named).contains("guide, other"))
    }

    @Test("a build with no index says so")
    func missingIndex() throws {
        for name in [MCPTools.docsSearch, MCPTools.docsGet] {
            let result = try MCPDocsToolsTests.call(
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
    @Test("an index with an empty page or section is no index")
    func malformedIndexIsRefused() {
        #expect(MCPDocsToolsTests.fixture.isWellFormed)
        let hollow = DocsIndex(pages: [
            DocsIndex.Page(
                page: "p",
                title: "P",
                description: "",
                sections: [MCPDocsToolsTests.section("p", "P", 1, [])]
            )
        ])
        #expect(!hollow.isWellFormed)
        #expect(!DocsIndex(pages: []).isWellFormed)
    }
}
