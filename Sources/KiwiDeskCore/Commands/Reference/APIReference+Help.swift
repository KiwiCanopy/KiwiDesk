import Foundation

/// The `help` / `list_commands` payload (#1033).
///
/// **One implementation, three callers.** The dispatcher's
/// `help` case returns this over the socket and to Lua, and the
/// CLI calls it directly rather than round-tripping static data
/// through a socket — see `CLIHelp` for why answering locally is
/// the ruling. Nothing may re-derive the listing beside a call
/// site; `CLIHelpSeamTests` scans for that.
extension APIReference {
    /// The whole surface, grouped — or one command's record when
    /// `name` is given.
    ///
    /// An unrecognised name fails with a did-you-mean hint, which
    /// is the answer `list_commands focus` silently withheld
    /// before (#1033).
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

    /// The full listing: a count, then the groups in print
    /// order.
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

    /// One command as JSON.
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

    /// One argument as JSON. `values` appears only on an
    /// enum-typed argument, read off the Swift type rather than
    /// typed here.
    ///
    /// **The Swift type's NAME is deliberately not on the wire.**
    /// `APIChoice.type` carries it and the terminal rendering
    /// prints it, because a human reading `help` is helped by
    /// knowing which decoder to go and read. Publishing it as a
    /// JSON field would make a Swift symbol part of the CLI's
    /// output contract, and AGENTS.md §5 actively encourages
    /// renaming those — a rename would then change documented
    /// output with nothing to notice. `values` is what answers
    /// "what may I send", and it is stable in the way the wire
    /// needs.
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

    /// A close name for an unknown one, over the WHOLE surface.
    ///
    /// Deliberately not `suggestion`, which must only hint at
    /// what the caller's channel can invoke (#37). Help is a
    /// lookup rather than an invocation: pointing a reader at
    /// `KiwiDesk.bind` when they typed `bnid` is the right
    /// answer even though the CLI cannot call it.
    public static func helpSuggestion(
        for unknown: String
    ) -> String? {
        closest(to: unknown, among: lookupNames)
    }

    /// Every name `help` answers to: each command's qualified
    /// name plus its Lua aliases.
    static let lookupNames: [String] = entries.flatMap {
        [$0.qualifiedName] + $0.aliases
    }
}
