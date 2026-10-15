import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The `diagnose_window` tool (#1685 ▸ Ruling 6d): one read-only
/// tool over `explain_window` and `explain_app`, its target
/// required — exactly one of `window` or `app`.
@Suite("MCP diagnose_window tool")
struct MCPDiagnoseToolTests {
    static func call(
        _ app: MCPKeepTests.FakeApp,
        _ arguments: [String: JSONValue]
    ) throws -> [String: JSONValue] {
        try MCPKeepTests.call(app, MCPTools.diagnoseWindow, arguments)
    }

    @Test("both verbs back the tool and run may send them")
    func entriesAreSendable() {
        #expect(
            MCPTools.diagnoseEntries.map(\.qualifiedName)
                == ["explain_window", "explain_app"]
        )
        for entry in MCPTools.diagnoseEntries {
            #expect(MCPTools.isRunnable(entry), "\(entry.name)")
            #expect(!APIReference.isDestructive(entry), "\(entry.name)")
        }
    }

    @Test("a window sends explain_window, an app explain_app")
    func targetPicksTheVerb() throws {
        let app = MCPKeepTests.FakeApp()
        _ = try Self.call(app, ["window": .number(7)])
        #expect(app.sent.last?.command == "explain_window")
        #expect(app.sent.last?.args == [.number(7)])
        _ = try Self.call(app, ["app": .string("com.example.app")])
        #expect(app.sent.last?.command == "explain_app")
        #expect(app.sent.last?.args == [.string("com.example.app")])
    }

    @Test(
        "no target or both targets is refused and sends nothing",
        arguments: [
            [:],
            ["window": JSONValue.number(7), "app": .string("x")],
        ] as [[String: JSONValue]]
    )
    func targetIsRequired(_ arguments: [String: JSONValue]) throws {
        let app = MCPKeepTests.FakeApp()
        let result = try Self.call(app, arguments)
        #expect(result["isError"] == .bool(true))
        #expect(app.sent.isEmpty)
    }

    @Test("the tool is read-only and types its targets")
    func schemaIsReadOnly() {
        guard case .array(let tools) = MCPTools().definitions else {
            Issue.record("no tools")
            return
        }
        let tool = tools.first {
            if case .object(let fields) = $0 {
                return fields["name"] == .string(MCPTools.diagnoseWindow)
            }
            return false
        }
        guard case .object(let fields)? = tool,
            case .object(let notes)? = fields["annotations"],
            case .object(let input)? = fields["inputSchema"],
            case .object(let properties)? = input["properties"]
        else {
            Issue.record("diagnose_window is not listed")
            return
        }
        #expect(notes["readOnlyHint"] == .bool(true))
        #expect(
            MCPGroupToolTests.member(properties["window"], "type")
                == .string("integer")
        )
        #expect(
            MCPGroupToolTests.member(properties["app"], "type")
                == .string("string")
        )
    }
}
