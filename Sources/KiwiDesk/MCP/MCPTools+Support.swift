import Foundation
import KiwiDeskCore

/// The sentences the server says more than once (#1685), each
/// stated here and nowhere beside it.
enum MCPWording {
    /// Nothing over the socket writes a setting to disk, so a
    /// `set_*` value lasts until something replaces the live
    /// settings (#1685 ▸ Ruling 4). An app-wide value outlives a
    /// profile load, hence "may".
    static let temporary =
        "A setting changed with a set_* command is temporary: it "
        + "lasts at most until the next config reload or restart, "
        + "and a profile load may replace it sooner."

    /// Why a call got no answer: no app to connect to, or an app
    /// that took the request and did not reply in time.
    static func unanswered(_ error: Error) -> String {
        switch error {
        case SocketError.connectFailed, SocketError.pathTooLong:
            return "KiwiDesk is not reachable. Is the app running? "
                + "(\(error))"
        default:
            return "KiwiDesk did not answer; the command may have run. "
                + "(\(error))"
        }
    }
}

/// The readings and result shapes the tools share (#1685).
extension MCPTools {
    /// `set_*` verbs that write their own file rather than a
    /// running value, so no temporary note follows them.
    static let savingSetters: Set<String> = ["set_default_profile"]

    /// A `set_*` verb that changes a running value. A further
    /// verb writing a file under a `set_*` name joins
    /// `savingSetters`; nothing scans for one, so review owes it
    /// until the keep ledger reports what changed instead.
    static func isSetter(_ command: String) -> Bool {
        let verb = command.split(separator: ".").last ?? ""
        return verb.hasPrefix("set_") && !savingSetters.contains(command)
    }

    /// A command the socket answers: Lua-only verbs have no
    /// command, and `subscribe` streams instead of answering.
    static func isRunnable(_ entry: APIEntry) -> Bool {
        entry.command != nil
            && entry.qualifiedName != APIReference.socketOnlyCommand
    }

    /// The socket request a tool's `command` and `args` describe,
    /// or why that tool may not send it. A name the binary does not
    /// know is refused, never forwarded, so no command reaches the
    /// app past the destructive check; an alias is sent as the
    /// command it names.
    static func request(
        from fields: [String: JSONValue],
        destructive: Bool
    ) -> Result<CommandRequest, MCPToolRefusal> {
        guard let name = fields["command"]?.stringValue, !name.isEmpty
        else {
            return .failure(MCPToolRefusal("needs a command"))
        }
        guard let entry = APIReference.entry(named: name) else {
            let answer = APIReference.helpResponse(for: name)
            return .failure(
                MCPToolRefusal(answer.error ?? "unknown command: \(name)")
            )
        }
        guard isRunnable(entry), let command = entry.command else {
            return .failure(
                MCPToolRefusal(
                    "\(entry.qualifiedName) is not available over MCP"
                )
            )
        }
        switch (APIReference.isDestructive(entry), destructive) {
        case (true, false):
            return .failure(
                MCPToolRefusal(
                    "\(entry.qualifiedName) cannot be undone: call "
                        + "run_destructive, which asks the user first"
                )
            )
        case (false, true):
            return .failure(
                MCPToolRefusal(
                    "\(entry.qualifiedName) is not destructive: call run"
                )
            )
        default:
            break
        }
        switch fields["args"] {
        case nil, .null?:
            return .success(CommandRequest(command: command))
        case .array(let given)?:
            return .success(
                CommandRequest(
                    command: command,
                    args: given.isEmpty ? nil : given
                )
            )
        default:
            return .failure(MCPToolRefusal("args must be an array"))
        }
    }

    /// A tool result: the text the model reads, and the same
    /// answer as structure. The structure is always an object,
    /// which the legacy revisions require.
    static func result(_ text: String, structured: JSONValue) -> JSONValue {
        .object([
            "content": content(text),
            "structuredContent": wrapped(structured),
            "isError": .bool(false),
        ])
    }

    static func failure(
        _ text: String,
        structured: JSONValue? = nil
    ) -> JSONValue {
        var fields: [String: JSONValue] = [
            "content": content(text),
            "isError": .bool(true),
        ]
        if let structured { fields["structuredContent"] = wrapped(structured) }
        return .object(fields)
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

    private static func content(_ text: String) -> JSONValue {
        .array([.object(["type": .string("text"), "text": .string(text)])])
    }
}

/// Why a tool call cannot be built; answered as a tool error.
struct MCPToolRefusal: Error {
    let reason: String

    init(_ reason: String) { self.reason = reason }
}
