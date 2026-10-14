import Foundation
import KiwiDeskCore

/// The sentences the server says more than once (#1685), each
/// stated here and nowhere beside it.
enum MCPWording {
    /// How a command's live changes are told (#1685 ▸ Ruling 4):
    /// the model tells the user once per task, not per setter.
    static let liveNotKept =
        "A setting a command changes is live and not kept: tell the "
        + "user once per task, and call keep when they want it to "
        + "last — at once if they asked for that (\"from now on\")."

    /// The pending changes and where `keep` would write them.
    static func unkept(
        _ pending: [TouchedLeaf],
        profile: String?
    ) -> String {
        let place =
            profile.map { "the profile \"\($0)\"" }
            ?? "the live profile"
        let look =
            pending.contains { $0.owner == .sharedLook }
            ? ", look changes into the shared look its profiles wear"
            : ""
        return "Not kept yet: \(pending.count) setting change(s), "
            + "live until a config reload, profile load or restart. "
            + "keep writes them into \(place)\(look)."
    }

    /// Why one leaf cannot be kept.
    static func unkeepable(_ leaf: TouchedLeaf) -> String {
        let why: String
        switch leaf.notKeepable ?? .unknown {
        case .luaOwned:
            why =
                "init.lua owns this config, and its next reload "
                + "restores Lua's value"
        case .noProfile:
            why =
                "no saved profile is live, so it lasts until the "
                + "next layout or profile change"
        case .appWide:
            why =
                "it is app-wide and lasts until KiwiDesk restarts; "
                + "Settings ▸ General keeps it"
        case .temporarySpace:
            why = "that Space is not in the profile"
        case .notWritten:
            why =
                "the write did not land; the profile or gui.json "
                + "was not written"
        case .conflicting:
            why =
                "it cannot be written into the profile together "
                + "with the changes kept beside it; keep it on its own"
        case .unknown:
            why = "it is not a setting keep can write"
        }
        return "\(leaf.id) cannot be kept: \(why)."
    }

    static func replaced(_ count: Int) -> String {
        "Something else — a config reload, a profile load, Settings "
            + "or another tool — changed \(count) unkept setting(s) "
            + "since; keep would no longer write this session's value, "
            + "so they are dropped."
    }

    static func kept(
        _ leaves: [TouchedLeaf],
        profile: String?,
        followers: JSONValue?
    ) -> String {
        var text = "Kept \(leaves.count) change(s)"
        if let profile { text += " in the profile \"\(profile)\"" }
        text += "."
        if case .array(let names)? = followers {
            let list = names.compactMap(\.stringValue)
                .joined(separator: ", ")
            text +=
                " The shared look changed for every profile wearing "
                + "it: \(list)."
        }
        return text
    }

    static let nothingToKeep = "Nothing to keep: no pending changes."

    static func notPending(_ id: String) -> String {
        "\(id) is not a pending change; keep takes ids from "
            + "keep_status.live_not_kept"
    }

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
    /// A command `run` may send: Lua-only verbs have no command,
    /// `subscribe` streams instead of answering, and a keep goes
    /// through the `keep` tool alone.
    static func isRunnable(_ entry: APIEntry) -> Bool {
        entry.command != nil
            && entry.qualifiedName != APIReference.socketOnlyCommand
            && entry.qualifiedName != keepCommand
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
        guard entry.qualifiedName != keepCommand else {
            return .failure(MCPToolRefusal("call keep instead"))
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
