import Foundation
import KiwiDeskCore

/// The readings and result shapes the tools share (#1685).
extension MCPTools {
    /// Told after every setter: nothing over the socket writes to
    /// disk, so a value lasts until something replaces the live
    /// settings (#1685 ▸ Ruling 4).
    static let temporaryNote =
        "This change is temporary: it lasts until the next profile "
        + "load, config reload or restart."

    /// A command the socket answers: Lua-only verbs have no
    /// command, and `subscribe` streams instead of answering.
    static func isRunnable(_ entry: APIEntry) -> Bool {
        entry.command != nil
            && entry.qualifiedName != APIReference.socketOnlyCommand
    }

    static func isDestructive(_ entry: APIEntry) -> Bool {
        APIReference.destructive.contains(entry.qualifiedName)
    }

    /// `set_*` verbs that write their own file rather than a
    /// running value, so no temporary note follows them.
    static let savingSetters: Set<String> = ["set_default_profile"]

    /// A `set_*` verb that changes a running value. A further
    /// verb writing a file under a `set_*` name joins
    /// `savingSetters`; nothing scans for one, so review owes it
    /// until the keep ledger reports what changed instead.
    static func isSetter(_ command: String) -> Bool {
        let verb = command.split(separator: ".").last ?? ""
        return verb.hasPrefix("set_")
            && !savingSetters.contains(command)
    }

    /// Why `command` may not go through the tool asked for, or
    /// nil. An unknown name is left to the app, which suggests
    /// the closest spelling.
    static func refusal(of command: String, _ destructive: Bool) -> String? {
        guard let entry = APIReference.entry(named: command) else {
            return nil
        }
        guard isRunnable(entry) else {
            return "\(entry.qualifiedName) is not available over MCP"
        }
        switch (isDestructive(entry), destructive) {
        case (true, false):
            return "\(entry.qualifiedName) cannot be undone: call "
                + "run_destructive, which asks the user first"
        case (false, true):
            return "\(entry.qualifiedName) is not destructive: "
                + "call run"
        default:
            return nil
        }
    }

    /// The socket request a tool's `command` and `args` describe,
    /// an alias sent as the command it names.
    static func request(
        from fields: [String: JSONValue]
    ) -> Result<CommandRequest, MCPToolRefusal> {
        guard let name = fields["command"]?.stringValue, !name.isEmpty
        else {
            return .failure(MCPToolRefusal("needs a command"))
        }
        var args: [JSONValue]?
        switch fields["args"] {
        case nil, .null?:
            args = nil
        case .array(let given)?:
            args = given.isEmpty ? nil : given
        default:
            return .failure(MCPToolRefusal("args must be an array"))
        }
        let command = APIReference.entry(named: name)?.command ?? name
        return .success(CommandRequest(command: command, args: args))
    }

    /// A tool result: the text the model reads, and the same
    /// answer as structure. The structure is always an object,
    /// which the legacy revisions require.
    static func result(_ text: String, structured: JSONValue) -> JSONValue {
        .object([
            "content": .array([
                .object(["type": .string("text"), "text": .string(text)])
            ]),
            "structuredContent": wrapped(structured),
            "isError": .bool(false),
        ])
    }

    static func failure(_ text: String) -> JSONValue {
        .object([
            "content": .array([
                .object(["type": .string("text"), "text": .string(text)])
            ]),
            "isError": .bool(true),
        ])
    }

    static func failure(_ refusal: MCPToolRefusal) -> JSONValue {
        failure(refusal.reason)
    }

    static func wrapped(_ value: JSONValue) -> JSONValue {
        if case .object = value { return value }
        return .object(["value": value])
    }

    /// Compact JSON for the model to read.
    static func text(of value: JSONValue) -> String {
        if case .string(let text) = value { return text }
        return CLIOutput.render(value, pretty: false) ?? ""
    }
}

/// Why a tool call cannot be built; answered as a tool error.
struct MCPToolRefusal: Error {
    let reason: String

    init(_ reason: String) { self.reason = reason }
}
