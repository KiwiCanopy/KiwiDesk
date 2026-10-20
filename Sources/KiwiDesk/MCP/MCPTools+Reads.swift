import Foundation
import KiwiDeskCore

/// The read tools (#1685): the listing and help answer from this
/// binary's `APIReference`, so they work without the app.
extension MCPTools {
    static let listCommands = "list_commands"
    static let help = "help"
    static let getState = "get_state"

    static let listCommandsTool = Tool(
        name: listCommands,
        definition: MCPToolSchema.tool(
            listCommands,
            title: "List KiwiDesk commands",
            "Lists the commands run can send, one line each. Pass "
                + "filter to keep only names, groups or summaries "
                + "containing it.",
            properties: [
                "filter": MCPToolSchema.string("Text to match, any case.")
            ],
            readOnly: true
        ),
        handle: { _, arguments in
            listing(filter: arguments["filter"]?.stringValue)
        }
    )

    static let helpTool = Tool(
        name: help,
        definition: MCPToolSchema.tool(
            help,
            title: "Describe a KiwiDesk command",
            "Shows one command's arguments, their types and allowed "
                + "values, and whether it is destructive.",
            properties: ["name": MCPToolSchema.string("The command name.")],
            required: ["name"],
            readOnly: true
        ),
        handle: { _, arguments in
            describe(arguments["name"]?.stringValue)
        }
    )

    static let getStateTool = Tool(
        name: getState,
        definition: MCPToolSchema.tool(
            getState,
            title: "Read KiwiDesk state",
            "Returns the Spaces, their layouts and windows, the screens "
                + "and the focused window. Config Issues and the sync "
                + "folder's status come from run with "
                + "\(KiwiCore.configStatusCommand).",
            readOnly: true
        ),
        handle: { tools, _ in
            tools.forward(CommandRequest(command: "get_state"))
        }
    )

    static func listing(filter: String?) -> JSONValue {
        let needle = filter?.lowercased() ?? ""
        let rows = APIReference.groups.flatMap(\.entries).filter {
            isRunnable($0)
        }.filter { entry in
            needle.isEmpty
                || [entry.qualifiedName, entry.group, entry.record.summary]
                    .contains { $0.lowercased().contains(needle) }
        }
        let lines = rows.map { entry in
            let mark =
                APIReference.isDestructive(entry) ? " [destructive]" : ""
            return "\(entry.qualifiedName) — \(entry.record.summary)\(mark)"
        }
        let text =
            lines.isEmpty
            ? "No command matches \"\(filter ?? "")\"."
            : lines.joined(separator: "\n")
        let commands = rows.map { entry -> JSONValue in
            .object([
                "name": .string(entry.qualifiedName),
                "summary": .string(entry.record.summary),
                "destructive": .bool(APIReference.isDestructive(entry)),
            ])
        }
        return result(
            text,
            structured: .object(["commands": .array(commands)])
        )
    }

    static func describe(_ name: String?) -> JSONValue {
        guard let name, !name.isEmpty else {
            return failure("help needs a command name")
        }
        let response = APIReference.helpResponse(for: name)
        guard response.isSuccess, let data = response.data else {
            return failure(response.error ?? "no answer")
        }
        return result(text(of: data), structured: data)
    }
}
