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

    /// This server's unkept changes, shared by every copy.
    let ledger = MCPKeepLedger()

    /// One tool: what a client lists, and what a call runs.
    struct Tool: Sendable {
        let name: String
        let definition: JSONValue
        let handle: @Sendable (MCPTools, [String: JSONValue]) -> JSONValue
    }

    /// Every tool, in a fixed order so a client can cache the
    /// list. The one copy: `definitions` and `call` both read it.
    static let all: [Tool] = [
        listCommandsTool, helpTool, getStateTool,
        runTool, runBatchTool, runDestructiveTool, keepTool,
    ]

    var definitions: JSONValue { .array(Self.all.map(\.definition)) }

    /// `tools/call`. A malformed call is a protocol error; a
    /// command KiwiDesk refuses is a tool result with `isError`,
    /// so the model can read the reason and correct itself.
    func call(_ params: [String: JSONValue]) throws -> JSONValue {
        guard let name = params["name"]?.stringValue else {
            throw MCPFailure(.invalidParams, "tools/call needs a name")
        }
        guard let tool = Self.all.first(where: { $0.name == name })
        else {
            throw MCPFailure(.invalidParams, "unknown tool: \(name)")
        }
        var arguments: [String: JSONValue] = [:]
        if case .object(let given)? = params["arguments"] {
            arguments = given
        }
        return tool.handle(self, arguments)
    }

    /// How long a call waits for the app's answer.
    static let answerTimeout = 10

    /// The default `send`: one bounded connection per call, so a
    /// hung app cannot hang the client.
    static func sendToApp(_ request: CommandRequest) throws -> CommandResponse
    {
        try AppSocket.connect(timeout: answerTimeout).roundTrip(request)
    }
}
