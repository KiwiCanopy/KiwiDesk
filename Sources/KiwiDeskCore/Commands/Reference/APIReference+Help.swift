import Foundation

/// Help and command listing response generation
/// (`CLIHelp`, `CLIHelpSeamTests`, #1033).
extension APIReference {
    /// Command listing or detailed single command record (#1033).
    public static func helpResponse(
        for name: String? = nil
    ) -> CommandResponse {
        guard let name, !name.isEmpty else {
            return .ok(listingJSON)
        }
        guard let entry = entry(named: name) else {
            guard let hint = helpSuggestion(for: name) else {
                return .fail("unknown command: \(name)")
            }
            return .fail(
                "unknown command: \(name) (did you mean "
                    + "\(hint)?)"
            )
        }
        return .ok(json(for: entry))
    }

    /// Full grouped command listing as JSON.
    static var listingJSON: JSONValue {
        let all = groups
        return .object([
            "commands": .number(
                Double(all.reduce(0) { $0 + $1.entries.count })
            ),
            "groups": .array(
                all.map { group in
                    .object([
                        "name": .string(group.name),
                        "commands": .array(
                            group.entries.map(json(for:))
                        ),
                    ])
                }
            ),
        ])
    }

    /// Serializes APIEntry to JSON representation.
    static func json(for entry: APIEntry) -> JSONValue {
        var object: [String: JSONValue] = [
            "name": .string(entry.name),
            "qualified_name": .string(entry.qualifiedName),
            "group": .string(entry.group),
            "channel": .string(entry.channel.rawValue),
            "summary": .string(entry.record.summary),
            "arguments": .array(
                entry.record.arguments.map(json(for:))
            ),
        ]
        if let command = entry.command {
            object["command"] = .string(command)
        }
        if !entry.aliases.isEmpty {
            object["aliases"] = .array(
                entry.aliases.map(JSONValue.string)
            )
        }
        return .object(object)
    }

    /// Serializes APIArgument to JSON (`APIChoice.type`, AGENTS.md §5).
    static func json(for argument: APIArgument) -> JSONValue {
        var object: [String: JSONValue] = [
            "name": .string(argument.name),
            "type": .string(argument.kind.wireName),
            "optional": .bool(argument.isOptional),
        ]
        if case .choice(let choice) = argument.kind {
            object["values"] = .array(
                choice.values.map(JSONValue.string)
            )
        }
        return .object(object)
    }

    /// Suggests closest matching command name across entire surface (#37).
    public static func helpSuggestion(
        for unknown: String
    ) -> String? {
        closest(to: unknown, among: lookupNames)
    }

    /// Qualified command names and aliases recognized by help.
    static let lookupNames: [String] = entries.flatMap {
        [$0.qualifiedName] + $0.aliases
    }
}
