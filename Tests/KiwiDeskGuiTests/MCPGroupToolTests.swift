import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Every domain tool over a command group (#1685 ▸ Ruling 2),
/// walked from `MCPTools.groupTools`: a tool joins these clauses by
/// being registered.
@Suite("MCP group tools")
struct MCPGroupToolTests {
    /// A listed tool's input properties, by name.
    static func properties(of name: String) -> [String: JSONValue] {
        guard case .array(let tools) = MCPTools().definitions else {
            return [:]
        }
        for case .object(let tool) in tools
        where tool["name"]?.stringValue == name {
            if case .object(let input)? = tool["inputSchema"],
                case .object(let fields)? = input["properties"]
            {
                return fields
            }
        }
        return [:]
    }

    static func member(_ value: JSONValue?, _ key: String) -> JSONValue? {
        if case .object(let members)? = value { return members[key] }
        return nil
    }

    @Test("every registered tool is listed once")
    func registeredToolsAreListed() {
        #expect(!MCPTools.groupTools.isEmpty)
        let names = MCPTools.all.map(\.name)
        for spec in MCPTools.groupTools {
            #expect(names.filter { $0 == spec.name }.count == 1)
        }
    }

    @Test("actions are the group's entries run would send")
    func actionsAreSendable() {
        for spec in MCPTools.groupTools {
            let all = MCPTools.groupEntries(spec.group)
            #expect(!all.isEmpty, "\(spec.group)")
            let sendable = all.filter {
                MCPTools.isRunnable($0) && !APIReference.isDestructive($0)
            }
            let listed = Self.member(
                Self.properties(of: spec.name)["action"],
                "enum"
            )
            #expect(
                listed == .array(sendable.map { .string($0.name) }),
                "\(spec.name)"
            )
        }
    }

    @Test("one name is one argument, typed from its kind")
    func argumentsAgreeAndAreTyped() {
        for spec in MCPTools.groupTools {
            let properties = Self.properties(of: spec.name)
            let arguments = MCPTools.offered(group: spec.group)
                .flatMap(\.record.arguments)
            #expect(
                Set(properties.keys)
                    == Set(arguments.map(\.name)).union(["action"]),
                "\(spec.name)"
            )
            for argument in arguments {
                let first = arguments.first { $0.name == argument.name }
                #expect(first?.kind == argument.kind, "\(argument.name)")
                #expect(
                    Self.member(properties[argument.name], "type")
                        == Self.jsonType(of: argument.kind),
                    "\(spec.name).\(argument.name)"
                )
            }
        }
    }

    /// The JSON type each kind's property carries, stated here
    /// rather than read off `MCPToolSchema.property`, the code the
    /// clause checks; a new kind fails to compile until it is
    /// listed.
    static func jsonType(of kind: APIArgumentKind) -> JSONValue? {
        switch kind {
        case .number: return .string("number")
        case .integer, .desktop, .window: return .string("integer")
        case .boolean: return .string("boolean")
        case .text, .color, .choice: return .string("string")
        case .space: return .array([.string("string"), .string("integer")])
        case .callback, .table: return nil
        }
    }

    /// A distinct value for the argument at `index`, of its kind.
    static func sample(_ argument: APIArgument, _ index: Int) -> JSONValue {
        switch argument.kind {
        case .number, .integer, .desktop, .window:
            return .number(Double(index + 1))
        case .boolean: return .bool(index % 2 == 0)
        case .choice(let choice):
            return .string(choice.values[index % choice.values.count])
        default: return .string("\(argument.name)-\(index)")
        }
    }

    /// A call naming every argument sends them in the record's
    /// positional order, never the call's key order.
    @Test("arguments are sent in the record's order")
    func argumentsKeepTheirOrder() {
        var checked = 0
        for spec in MCPTools.groupTools {
            for entry in MCPTools.offered(group: spec.group)
            where entry.record.arguments.count > 1 {
                let app = MCPKeepTests.FakeApp()
                let arguments = entry.record.arguments
                var call: [String: JSONValue] = [
                    "action": .string(entry.name)
                ]
                for (index, argument) in arguments.enumerated() {
                    call[argument.name] = Self.sample(argument, index)
                }
                _ = app.tools.runGroupAction(group: spec.group, call)
                let expected = arguments.enumerated().map {
                    Self.sample($0.element, $0.offset)
                }
                #expect(
                    app.sent.last?.command == entry.qualifiedName,
                    "\(entry.qualifiedName)"
                )
                #expect(
                    app.sent.last?.args == expected,
                    "\(entry.qualifiedName)"
                )
                checked += 1
            }
        }
        #expect(checked > 0)
    }

    @Test("a window argument is an integer id")
    func windowIsAnInteger() {
        let built = MCPToolSchema.property(for: .window("window"), "")
        #expect(Self.member(built, "type") == .string("integer"))
    }
}
