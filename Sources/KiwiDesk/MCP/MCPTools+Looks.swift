import Foundation
import KiwiDeskCore

/// The `looks` tool (#1685 ▸ Ruling 2, 6b): the `look.*` verbs as
/// one tool. Its actions and arguments are read off the verbs'
/// `APIRecord`s; a destructive verb is no action here and goes
/// through `run_destructive` (`APIReference.destructive`).
extension MCPTools {
    static let looks = "looks"

    /// The command group the tool wraps.
    static let lookGroup = "look"

    /// The `look.*` entries the tool offers, in declaration order.
    static var lookEntries: [APIEntry] {
        let group = APIReference.groups.first { $0.name == lookGroup }
        return (group?.entries ?? []).filter {
            isRunnable($0) && !APIReference.isDestructive($0)
        }
    }

    /// The argument properties of every action, each name once.
    static var lookArguments: [APIArgument] {
        var seen: Set<String> = []
        return lookEntries.flatMap(\.record.arguments).filter {
            seen.insert($0.name).inserted
        }
    }

    static let looksTool = Tool(
        name: looks,
        definition: MCPToolSchema.tool(
            looks,
            title: "Make and wear KiwiDesk looks",
            "Lists, inspects, wears and saves looks: the colors and "
                + "styling of borders and the KiwiShelf bars. current "
                + "names the setter of each look path; change one with "
                + "run, then save it as a new look. "
                + lookEntries.map {
                    "\($0.name): \($0.record.summary)"
                }.joined(separator: " ")
                + " Deleting a look goes through run_destructive. "
                + MCPWording.liveNotKept,
            properties: looksProperties,
            required: ["action"]
        ),
        handle: { tools, arguments in
            tools.look(arguments)
        }
    )

    static var looksProperties: [String: JSONValue] {
        var properties: [String: JSONValue] = [
            "action": .object([
                "type": .string("string"),
                "enum": .array(lookEntries.map { .string($0.name) }),
            ])
        ]
        for argument in lookArguments {
            let users = lookEntries.filter {
                $0.record.arguments.contains(argument)
            }.map(\.name)
            properties[argument.name] = MCPToolSchema.string(
                "For " + users.joined(separator: ", ") + "."
            )
        }
        return properties
    }

    /// Sends the action's `look.*` command, its arguments in the
    /// record's order, through the same check `run` applies.
    func look(_ arguments: [String: JSONValue]) -> JSONValue {
        let action = arguments["action"]?.stringValue ?? ""
        guard
            let entry = Self.lookEntries.first(where: {
                $0.name == action
            })
        else {
            let names = Self.lookEntries.map(\.name)
            return Self.failure(
                "action must be one of: "
                    + names.joined(separator: ", ")
            )
        }
        var args: [JSONValue] = []
        for argument in entry.record.arguments {
            guard let value = arguments[argument.name] else {
                if argument.isOptional { break }
                return Self.failure("\(action) needs \(argument.name)")
            }
            args.append(value)
        }
        let fields: [String: JSONValue] = [
            "command": .string(entry.qualifiedName),
            "args": .array(args),
        ]
        switch Self.request(from: fields, destructive: false) {
        case .failure(let refusal):
            return Self.failure(refusal.reason)
        case .success(let request):
            return forward(request)
        }
    }
}
