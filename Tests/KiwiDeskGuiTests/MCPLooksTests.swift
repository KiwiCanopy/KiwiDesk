import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The `looks` tool (#1685 ▸ Ruling 2, 6b): its actions are the
/// `look.*` records the destructive register leaves to `run`, it
/// sends exactly the record's command, and a worn look's change
/// is kept through the same ledger as any setter's.
@Suite("MCP looks tool")
struct MCPLooksTests {
    typealias FakeApp = MCPKeepTests.FakeApp

    static func looks(
        _ app: FakeApp,
        _ arguments: [String: JSONValue]
    ) throws -> [String: JSONValue] {
        try MCPKeepTests.call(app, MCPTools.looks, arguments)
    }

    /// The tool's schema, as a client lists it.
    static var schema: [String: JSONValue] {
        guard case .array(let tools) = MCPTools().definitions else {
            return [:]
        }
        for case .object(let tool) in tools
        where tool["name"]?.stringValue == MCPTools.looks {
            if case .object(let input)? = tool["inputSchema"],
                case .object(let properties)? = input["properties"]
            {
                return properties
            }
        }
        return [:]
    }

    static var actions: [String] {
        guard case .object(let action)? = schema["action"],
            case .array(let values)? = action["enum"]
        else { return [] }
        return values.compactMap(\.stringValue)
    }

    @Test("every action is a look record run may send")
    func actionsAreRunnableRecords() {
        let group = APIReference.groups.first { $0.name == "look" }
        let all = group?.entries ?? []
        #expect(!all.isEmpty)
        let runnable = all.filter { !APIReference.isDestructive($0) }
        #expect(Self.actions == runnable.map(\.name))
        #expect(!Self.actions.isEmpty)
        for action in Self.actions {
            let entry = APIReference.entry(named: "look.\(action)")
            #expect(entry.map(MCPTools.isRunnable) == true, "\(action)")
        }
        // A destructive look verb stays run_destructive's.
        let destructive = all.filter(APIReference.isDestructive)
        #expect(!destructive.isEmpty)
        for entry in destructive {
            #expect(!Self.actions.contains(entry.name))
        }
    }

    @Test("every record argument is a property")
    func argumentsAreProperties() {
        let offered = MCPTools.offered(group: MCPTools.lookGroup)
        let arguments = offered.flatMap(\.record.arguments)
        let names = Set(arguments.map(\.name))
        #expect(!names.isEmpty)
        #expect(Set(Self.schema.keys) == names.union(["action"]))
        // One name, one argument: the schema keeps the first.
        for argument in arguments {
            let first = arguments.first { $0.name == argument.name }
            #expect(first?.kind == argument.kind, "\(argument.name)")
        }
        for argument in arguments {
            let built = MCPToolSchema.property(for: argument, "")
            #expect(
                Self.schema[argument.name]?["type"] == built["type"],
                "\(argument.name)"
            )
        }
    }

    @Test("a property's type and values come from the kind")
    func propertyFollowsKind() {
        let mode = APIArgument.choice("mode", LayoutMode.self)
        guard
            case .object(let fields) = MCPToolSchema.property(
                for: mode,
                ""
            ),
            case .array(let values)? = fields["enum"]
        else {
            Issue.record("a choice has no enum")
            return
        }
        #expect(
            values.compactMap(\.stringValue)
                == LayoutMode.allCases.map(\.rawValue)
        )
        let flag = MCPToolSchema.property(for: .boolean("on"), "")
        guard case .object(let flagFields) = flag else { return }
        #expect(flagFields["type"] == .string("boolean"))
    }

    @Test("a later argument never skips an omitted earlier one")
    func positionalGapIsRefused() {
        let app = FakeApp()
        let core = MCPTools.offered(group: APIReference.coreGroup)
        #expect(core.contains { $0.name == "create_space" })
        let refused = app.tools.runGroupAction(
            group: APIReference.coreGroup,
            [
                "action": .string("create_space"),
                "space": .string("9"),
                "scope": .string("profile"),
            ]
        )
        guard case .object(let fields) = refused else { return }
        #expect(fields["isError"] == .bool(true))
        #expect(MCPKeepTests.text(fields).contains("needs mode"))
        #expect(app.sent.isEmpty)
    }

    @Test("an action sends its command with the record's arguments")
    func applySends() throws {
        let app = FakeApp()
        let result = try Self.looks(
            app,
            ["action": .string("apply"), "name": .string("Dusk")]
        )
        #expect(result["isError"] == .bool(false))
        #expect(app.sent.last?.command == "look.apply")
        #expect(app.sent.last?.args == [.string("Dusk")])
        _ = try Self.looks(app, ["action": .string("list")])
        #expect(app.sent.last?.command == "look.list")
        #expect(app.sent.last?.args == nil)
    }

    @Test("a missing argument or unknown action sends nothing")
    func refusalsSendNothing() throws {
        let app = FakeApp()
        let bare = try Self.looks(app, ["action": .string("apply")])
        #expect(bare["isError"] == .bool(true))
        let delete = try Self.looks(
            app,
            ["action": .string("delete"), "name": .string("Dusk")]
        )
        #expect(delete["isError"] == .bool(true))
        #expect(app.sent.isEmpty)
    }

    @Test("a worn look on a follower keeps into the shared look")
    func wornLookKeepsShared() throws {
        let app = FakeApp()
        let id = "/settings/kiwishelf/thickness"
        app.touched["look.apply"] = [MCPKeepTests.leaf(id, .sharedLook)]
        let worn = try Self.looks(
            app,
            ["action": .string("apply"), "name": .string("Dusk")]
        )
        #expect(MCPKeepTests.status(worn)?["pending"] == .number(1))
        #expect(MCPKeepTests.text(worn).contains("shared look"))
        app.keepAnswer = .object([
            "profile": .string("Work"),
            "kept": .array([
                .object([
                    "id": .string(id),
                    "owner": .string("shared_look"),
                ])
            ]),
            "followers": .array([.string("Home"), .string("Work")]),
        ])
        let kept = try MCPKeepTests.call(app, MCPTools.keep)
        #expect(app.sent.last?.command == MCPTools.keepCommand)
        #expect(app.sent.last?.args == [.string(id)])
        #expect(MCPKeepTests.text(kept).contains("Home, Work"))
    }
}

extension JSONValue {
    /// An object's member, or nil for any other value.
    fileprivate subscript(_ key: String) -> JSONValue? {
        if case .object(let members) = self { return members[key] }
        return nil
    }
}
