import Foundation
import KiwiDeskCore

/// The tools `kiwidesk mcp` offers (#1685): few and generic, since
/// every tool's description costs the model context on every turn.
/// A command reaches the app through `run`; which tool may run it
/// is `APIReference.destructive`'s answer, never a list here.
struct MCPTools {
    /// Sends one request to the running app. Tests inject a fake;
    /// the default connects to the app's socket per call, so a
    /// relaunched app is reached again.
    var send: (CommandRequest) throws -> CommandResponse =
        MCPTools.sendToApp

    static let listCommands = "list_commands"
    static let help = "help"
    static let getState = "get_state"
    static let run = "run"
    static let runBatch = "run_batch"
    static let runDestructive = "run_destructive"

    /// Longest batch one call may carry.
    static let batchLimit = 100

    /// Every tool, in a fixed order so a client can cache it.
    var definitions: JSONValue {
        .array([
            Self.tool(
                Self.listCommands,
                title: "List KiwiDesk commands",
                "Lists the commands run can send, one line each. "
                    + "Pass filter to keep only names, groups or "
                    + "summaries containing it.",
                properties: [
                    "filter": Self.string("Text to match, any case.")
                ],
                readOnly: true
            ),
            Self.tool(
                Self.help,
                title: "Describe a KiwiDesk command",
                "Shows one command's arguments, their types and "
                    + "allowed values, and whether it is destructive.",
                properties: ["name": Self.string("The command name.")],
                required: ["name"],
                readOnly: true
            ),
            Self.tool(
                Self.getState,
                title: "Read KiwiDesk state",
                "Returns the Spaces, their layouts and windows, the "
                    + "screens and the focused window.",
                readOnly: true
            ),
            Self.tool(
                Self.run,
                title: "Run a KiwiDesk command",
                "Runs one command that can be undone. Destructive "
                    + "commands are refused: use run_destructive. "
                    + "A change is temporary: it lasts until the "
                    + "next profile load, config reload or restart, "
                    + "so tell the user.",
                properties: Self.commandProperties,
                required: ["command"]
            ),
            Self.tool(
                Self.runBatch,
                title: "Run several KiwiDesk commands",
                "Runs commands in order and stops at the first "
                    + "failure. Refuses the whole batch if any "
                    + "command is destructive. Changes are temporary, "
                    + "as with run.",
                properties: [
                    "commands": .object([
                        "type": .string("array"),
                        "maxItems": .number(Double(Self.batchLimit)),
                        "items": .object([
                            "type": .string("object"),
                            "properties": .object(Self.commandProperties),
                            "required": .array([.string("command")]),
                        ]),
                    ])
                ],
                required: ["commands"]
            ),
            Self.tool(
                Self.runDestructive,
                title: "Run a destructive KiwiDesk command",
                "Runs one command that cannot be undone, such as "
                    + "deleting a Space or a profile, closing a "
                    + "window or loading a profile over unsaved "
                    + "changes. Ask the user before calling it.",
                properties: Self.commandProperties,
                required: ["command"],
                destructive: true
            ),
        ])
    }

    static let commandProperties: [String: JSONValue] = [
        "command": string("The command name, as list_commands shows it."),
        "args": .object([
            "type": .string("array"),
            "description": .string(
                "Positional arguments in the order help lists them."
            ),
            "items": .object([:]),
        ]),
    ]

    static func string(_ description: String) -> JSONValue {
        .object([
            "type": .string("string"),
            "description": .string(description),
        ])
    }

    static func tool(
        _ name: String,
        title: String,
        _ description: String,
        properties: [String: JSONValue] = [:],
        required: [String] = [],
        readOnly: Bool = false,
        destructive: Bool = false
    ) -> JSONValue {
        var schema: [String: JSONValue] = [
            "type": .string("object"),
            "properties": .object(properties),
            "additionalProperties": .bool(false),
        ]
        if !required.isEmpty {
            schema["required"] = .array(required.map(JSONValue.string))
        }
        return .object([
            "name": .string(name),
            "title": .string(title),
            "description": .string(description),
            "inputSchema": .object(schema),
            "annotations": .object([
                "title": .string(title),
                "readOnlyHint": .bool(readOnly),
                "destructiveHint": .bool(destructive),
                "idempotentHint": .bool(readOnly),
                "openWorldHint": .bool(false),
            ]),
        ])
    }

    /// The default `send`: one connection per call, bounded so a
    /// hung app cannot hang the client.
    static func sendToApp(_ request: CommandRequest) throws -> CommandResponse
    {
        let client = try SocketClient(path: KiwiCore.defaultSocketPath)
        client.setTimeout(seconds: 10)
        return try client.roundTrip(request)
    }
}
