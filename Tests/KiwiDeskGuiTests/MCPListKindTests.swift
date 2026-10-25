import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The MCP listing's `kind` filter (#2610): additive beside
/// `filter`, read from the one kind register, and refusing a kind
/// it does not know rather than listing everything.
@Suite("MCP list_commands kind")
struct MCPListKindTests {
    private static func structured(
        _ arguments: [String: JSONValue]
    ) throws -> (rows: [[String: JSONValue]], isError: Bool) {
        let tools = MCPToolsTests.FakeApp().tools
        let result = try MCPToolsTests.call(
            tools,
            MCPTools.listCommands,
            arguments
        )
        guard case .object(let body)? = result["structuredContent"],
            case .array(let commands)? = body["commands"]
        else { return ([], result["isError"] == .bool(true)) }
        let rows = commands.compactMap { row -> [String: JSONValue]? in
            guard case .object(let fields) = row else { return nil }
            return fields
        }
        return (rows, result["isError"] == .bool(true))
    }

    @Test("kind keeps only that kind, and every row names its kind")
    func kindFilters() throws {
        for kind in APIKind.allCases {
            let rows = try Self.structured(["kind": .string(kind.rawValue)])
            #expect(!rows.rows.isEmpty, "\(kind)")
            for row in rows.rows {
                #expect(row["kind"] == .string(kind.rawValue))
            }
        }
        let all = try Self.structured([:]).rows
        let actions = try Self.structured(["kind": .string("action")])
        #expect(actions.rows.count < all.count)
        #expect(all.allSatisfy { $0["kind"] != nil })
    }

    @Test("kind and filter narrow together")
    func kindWithFilter() throws {
        let rows = try Self.structured([
            "kind": .string("setting"), "filter": .string("gap"),
        ]).rows
        #expect(!rows.isEmpty)
        for row in rows {
            #expect(row["kind"] == .string("setting"))
        }
    }

    @Test("an unknown kind is refused")
    func unknownKindRefuses() throws {
        let answer = try Self.structured(["kind": .string("verb")])
        #expect(answer.isError)
        #expect(answer.rows.isEmpty)
    }

    @Test("the schema offers exactly the register's kinds")
    func schemaOffersTheKinds() {
        guard
            case .object(let definition) = MCPTools.listCommandsTool
                .definition,
            case .object(let schema)? = definition["inputSchema"],
            case .object(let properties)? = schema["properties"],
            case .object(let kind)? = properties["kind"],
            case .array(let values)? = kind["enum"]
        else {
            Issue.record("list_commands offers no kind")
            return
        }
        #expect(
            values == APIKind.allCases.map { .string($0.rawValue) }
        )
    }
}
