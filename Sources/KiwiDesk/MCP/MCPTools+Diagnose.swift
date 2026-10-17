import Foundation
import KiwiDeskCore

/// The `diagnose_window` tool (#1685 ▸ Ruling 2, 6d): one tool over
/// `explain_window` and `explain_app`. Which one it sends is decided
/// by the target named — exactly one of `window` or `app`, required
/// here though the CLI defaults to the focused window, since an AI
/// app's focus is its own chat window.
extension MCPTools {
    static let diagnoseWindow = "diagnose_window"

    /// The two verbs, in the order the target properties are read.
    static let diagnoseEntries: [APIEntry] = [
        "explain_window", "explain_app",
    ].compactMap(APIReference.entry(named:))

    static let diagnoseWindowTool = Tool(
        name: diagnoseWindow,
        definition: MCPToolSchema.tool(
            diagnoseWindow,
            title: "Explain a KiwiDesk window",
            "Why a window floats or tiles, which Space and app rules "
                + "it has, and what would change that. Pass window, "
                + "an id \(getState) lists, or app, a bundle_id, for a "
                + "window \(getState) does not list: KiwiDesk does not "
                + "manage it, and the answer says what it knows of the "
                + "app.",
            properties: entryProperties(diagnoseEntries),
            readOnly: true
        ),
        handle: { tools, arguments in
            tools.diagnose(arguments)
        }
    )

    /// Sends the one verb whose target `arguments` name.
    func diagnose(_ arguments: [String: JSONValue]) -> JSONValue {
        let named = Self.diagnoseEntries.filter { entry in
            entry.record.arguments.contains { arguments[$0.name] != nil }
        }
        guard named.count == 1, let entry = named.first else {
            return Self.failure("pass exactly one of window or app")
        }
        return send(entry, arguments)
    }
}
