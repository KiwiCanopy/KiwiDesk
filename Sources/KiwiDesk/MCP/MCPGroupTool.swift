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

    /// The entries' arguments, each name once; a name is one
    /// argument across them (`MCPGroupToolTests`).
    static func arguments(of entries: [APIEntry]) -> [APIArgument] {
        var seen: Set<String> = []
        return entries.flatMap(\.record.arguments).filter {
            seen.insert($0.name).inserted
        }
    }

    /// One property per argument of `entries`, typed from its kind
    /// — what a single-verb tool takes whole, and a group tool
    /// beside its `action`.
    static func entryProperties(
        _ entries: [APIEntry]
    ) -> [String: JSONValue] {
        var properties: [String: JSONValue] = [:]
        for argument in arguments(of: entries) {
            let users = entries.filter {
                $0.record.arguments.contains { $0.name == argument.name }
            }.map(\.name)
            properties[argument.name] = MCPToolSchema.property(
                for: argument,
                "For " + users.joined(separator: ", ") + "."
            )
        }
        return properties
    }

    /// A group tool as `MCPTools.all` lists it.
    static func groupTool(_ spec: GroupToolSpec) -> Tool {
        let actions = offered(group: spec.group)
        let destructive = groupEntries(spec.group)
            .filter(APIReference.isDestructive)
            .map(\.qualifiedName)
        var description =
            spec.lead + " "
            + actions.map { "\($0.name): \($0.record.summary)" }
            .joined(separator: " ")
        if !destructive.isEmpty {
            description +=
                " " + destructive.joined(separator: ", ")
                + " cannot be undone: call \(runDestructive)."
        }
        description += " " + MCPWording.liveNotKept
        var properties = entryProperties(actions)
        properties["action"] = .object([
            "type": .string("string"),
            "enum": .array(actions.map { .string($0.name) }),
        ])
        return Tool(
            name: spec.name,
            definition: MCPToolSchema.tool(
                spec.name,
                title: spec.title,
                description,
                properties: properties,
                required: ["action"]
            ),
            handle: { tools, arguments in
                tools.runGroupAction(group: spec.group, arguments)
            }
        )
    }

    /// Resolves `action` to one of the group's offered entries and
    /// sends it.
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
        return send(entry, arguments)
    }

    /// Sends one entry, its arguments in the record's positional
    /// order, through the same gate `run` applies. A later
    /// argument after an omitted optional is refused, even where
    /// the decoder lets it take that slot (`create_space`'s
    /// scope): the record cannot say so, and `run` sends it.
    func send(
        _ entry: APIEntry,
        _ arguments: [String: JSONValue]
    ) -> JSONValue {
        let action = entry.name
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

/// One group tool's identity: the register `MCPTools.groupTools`
/// holds, which `all` builds from and `MCPGroupToolTests` walks.
struct GroupToolSpec: Sendable {
    let name: String
    let group: String
    let title: String
    let lead: String
}
