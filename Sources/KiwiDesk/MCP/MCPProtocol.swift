import Foundation
import KiwiDeskCore

/// The MCP revisions `kiwidesk mcp` speaks, dual-era (#1685): a
/// modern request names its version in `_meta`, a legacy client
/// opens with `initialize`. The spec is re-checked on a schedule
/// (#2257).
enum MCPProtocol {
    /// Revisions served statelessly, version on every request.
    static let modern = ["2026-07-28"]
    /// Revisions served after an `initialize` handshake, newest
    /// first.
    static let legacy = ["2025-11-25", "2025-06-18"]

    static let versionKey = "io.modelcontextprotocol/protocolVersion"
    static let serverInfoKey = "io.modelcontextprotocol/serverInfo"

    /// How long a client may cache the tool list: the list
    /// changes only with the binary.
    static let listTTLMilliseconds = 3_600_000.0

    static var serverInfo: JSONValue {
        .object([
            "name": .string(MCPInvocation.serverName),
            "title": .string("KiwiDesk"),
            "version": .string(KiwiDeskVersion.semantic),
        ])
    }

    /// Guidance a client hands the model with the tools.
    static let instructions =
        "KiwiDesk is a tiling window manager for macOS. Find a "
        + "command with list_commands, read its arguments with help, "
        + "and run it with run (or run_batch for several). get_state "
        + "shows the Spaces and windows. Commands that cannot be "
        + "undone go only through run_destructive, so ask the user "
        + "before calling it. " + MCPWording.liveNotKept

    /// The version an `initialize` settles on: the client's if
    /// served, else the newest legacy one.
    static func negotiated(_ requested: String?) -> String {
        if let requested, legacy.contains(requested) {
            return requested
        }
        return legacy[0]
    }

    /// The refusal for a modern request naming a revision this
    /// server does not serve.
    static func unsupported(_ requested: String) -> MCPFailure {
        MCPFailure(
            .unsupportedProtocolVersion,
            "Unsupported protocol version",
            data: .object([
                "supported": .array(
                    (modern + legacy).map(JSONValue.string)
                ),
                "requested": .string(requested),
            ])
        )
    }

    static var capabilities: JSONValue {
        .object(["tools": .object(["listChanged": .bool(false)])])
    }

    /// `server/discover`'s result.
    static var discoverResult: JSONValue {
        .object([
            "resultType": .string("complete"),
            "supportedVersions": .array(
                (modern + legacy).map(JSONValue.string)
            ),
            "capabilities": capabilities,
            "_meta": .object([serverInfoKey: serverInfo]),
            "instructions": .string(instructions),
            "ttlMs": .number(listTTLMilliseconds),
            "cacheScope": .string("private"),
        ])
    }

    /// `initialize`'s result for a legacy client.
    static func initializeResult(version: String) -> JSONValue {
        .object([
            "protocolVersion": .string(version),
            "capabilities": capabilities,
            "serverInfo": serverInfo,
            "instructions": .string(instructions),
        ])
    }
}
