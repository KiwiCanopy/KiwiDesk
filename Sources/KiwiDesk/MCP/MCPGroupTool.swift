import Foundation
import KiwiDeskCore

/// A domain tool over one command group (#1685 ▸ Ruling 2): its
/// actions, arguments and argument types are read off the group's
/// `APIRecord`s, and an action is offered exactly when `run` would
/// send it, so the tool never advertises what its gate refuses.
extension MCPTools {
    /// The group's entries `run` may send, in declaration order.
    static func offered(group: String) -> [APIEntry] {
        groupEntries(group).filter { entry in
            let probe: [String: JSONValue] = [
                "command": .string(entry.qualifiedName)
            ]
            if case .success = request(from: probe, destructive: false) {
                return true
            }
            return false
        }
    }

    static func groupEntries(_ group: String) -> [APIEntry] {
        APIReference.groups.first { $0.name == group }?.entries ?? []
    }

    /// Every offered action's arguments, each name once; a name
    /// is one argument across the group (`MCPLooksTests`).
    static func groupArguments(_ group: String) -> [APIArgument] {
        var seen: Set<String> = []
        return offered(group: group).flatMap(\.record.arguments).filter {
            seen.insert($0.name).inserted
        }
    }

    static func groupTool(
        name: String,
        group: String,
        title: String,
        lead: String
    ) -> Tool {
        let actions = offered(group: group)
        let destructive = groupEntries(group)
            .filter(APIReference.isDestructive)
            .map(\.qualifiedName)
        var description =
            lead + " "
            + actions.map { "\($0.name): \($0.record.summary)" }
            .joined(separator: " ")
        if !destructive.isEmpty {
            description +=
                " " + destructive.joined(separator: ", ")
                + " cannot be undone: call \(runDestructive)."
        }
        description += " " + MCPWording.liveNotKept
        return Tool(
            name: name,
            definition: MCPToolSchema.tool(
                name,
                title: title,
                description,
                properties: groupProperties(group, actions: actions),
                required: ["action"]
            ),
            handle: { tools, arguments in
                tools.runGroupAction(group: group, arguments)
            }
        )
    }

    private static func groupProperties(
        _ group: String,
        actions: [APIEntry]
    ) -> [String: JSONValue] {
        var properties: [String: JSONValue] = [
            "action": .object([
                "type": .string("string"),
                "enum": .array(actions.map { .string($0.name) }),
            ])
        ]
        for argument in groupArguments(group) {
            let users = actions.filter {
                $0.record.arguments.contains { $0.name == argument.name }
            }.map(\.name)
            properties[argument.name] = MCPToolSchema.property(
                for: argument,
                "For " + users.joined(separator: ", ") + "."
            )
        }
        return properties
    }

    /// Sends the action's command, its arguments in the record's
    /// positional order, through the same gate `run` applies.
    func runGroupAction(
        group: String,
        _ arguments: [String: JSONValue]
    ) -> JSONValue {
        let action = arguments["action"]?.stringValue ?? ""
        let actions = Self.offered(group: group)
        guard let entry = actions.first(where: { $0.name == action })
        else {
            return Self.failure(
                "action must be one of: "
                    + actions.map(\.name).joined(separator: ", ")
            )
        }
        var args: [JSONValue] = []
        var omitted: String?
        for argument in entry.record.arguments {
            guard let value = arguments[argument.name] else {
                guard argument.isOptional else {
                    return Self.failure("\(action) needs \(argument.name)")
                }
                omitted = omitted ?? argument.name
                continue
            }
            // Positional: never drop a later argument silently.
            if let omitted {
                return Self.failure(
                    "\(action): \(argument.name) needs \(omitted) "
                        + "too; or send it with \(Self.run)"
                )
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
