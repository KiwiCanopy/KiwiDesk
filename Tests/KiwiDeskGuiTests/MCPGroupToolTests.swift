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
                let built = MCPToolSchema.property(for: argument, "")
                #expect(
                    Self.member(properties[argument.name], "type")
                        == Self.member(built, "type"),
                    "\(spec.name).\(argument.name)"
                )
            }
        }
    }

    @Test("a window argument is an integer id")
    func windowIsAnInteger() {
        let built = MCPToolSchema.property(for: .window("window"), "")
        #expect(Self.member(built, "type") == .string("integer"))
    }
}
