import Foundation
import KiwiDeskCore

/// The tools that send commands to the app (#1685 ▸ Ruling 3): a
/// destructive command goes only through `run_destructive`, the one
/// tool carrying MCP's destructive hint.
extension MCPTools {
    static let run = "run"
    static let runBatch = "run_batch"
    static let runDestructive = "run_destructive"

    /// Longest batch one call may carry.
    static let batchLimit = 100

    static let runTool = Tool(
        name: run,
        definition: MCPToolSchema.tool(
            run,
            title: "Run a KiwiDesk command",
            "Runs one command that can be undone. Destructive commands "
                + "are refused: use run_destructive. "
                + MCPWording.liveNotKept,
            properties: MCPToolSchema.command,
            required: ["command"]
        ),
        handle: { tools, arguments in
            tools.runOne(arguments, destructive: false)
        }
    )

    static let runBatchTool = Tool(
        name: runBatch,
        definition: MCPToolSchema.tool(
            runBatch,
            title: "Run several KiwiDesk commands",
            "Runs commands in order and stops at the first failure. "
                + "Refuses the whole batch if any command is "
                + "destructive. " + MCPWording.liveNotKept,
            properties: [
                "commands": .object([
                    "type": .string("array"),
                    "maxItems": .number(Double(batchLimit)),
                    "items": .object([
                        "type": .string("object"),
                        "properties": .object(MCPToolSchema.command),
                        "required": .array([.string("command")]),
                    ]),
                ])
            ],
            required: ["commands"]
        ),
        handle: { tools, arguments in
            tools.runBatch(arguments["commands"])
        }
    )

    static let runDestructiveTool = Tool(
        name: runDestructive,
        definition: MCPToolSchema.tool(
            runDestructive,
            title: "Run a destructive KiwiDesk command",
            "Runs one command that cannot be undone, such as deleting a "
                + "Space or a profile, closing a window or loading a "
                + "profile over unsaved changes. Ask the user before "
                + "calling it.",
            properties: MCPToolSchema.command,
            required: ["command"],
            destructive: true
        ),
        handle: { tools, arguments in
            tools.runOne(arguments, destructive: true)
        }
    )

    func runOne(
        _ arguments: [String: JSONValue],
        destructive: Bool
    ) -> JSONValue {
        switch Self.request(from: arguments, destructive: destructive) {
        case .failure(let refusal):
            return Self.failure(refusal.reason)
        case .success(let request):
            return forward(request)
        }
    }

    func runBatch(_ value: JSONValue?) -> JSONValue {
        guard case .array(let items)? = value, !items.isEmpty else {
            return Self.failure("run_batch needs a commands array")
        }
        guard items.count <= Self.batchLimit else {
            return Self.failure(
                "run_batch takes at most \(Self.batchLimit) commands"
            )
        }
        // Every command is checked before any runs, so a batch
        // never stops halfway for a reason it could know up front.
        var requests: [CommandRequest] = []
        for (index, item) in items.enumerated() {
            guard case .object(let fields) = item else {
                return Self.failure("commands[\(index)] is not an object")
            }
            switch Self.request(from: fields, destructive: false) {
            case .failure(let refusal):
                return Self.failure("commands[\(index)]: \(refusal.reason)")
            case .success(let request):
                requests.append(request)
            }
        }
        return MCPBatch(requests: requests, tools: self).run()
    }

    /// Sends one request and reports it as a tool result.
    func forward(_ request: CommandRequest) -> JSONValue {
        let outcome = outcome(of: request)
        guard outcome.ok else { return decorated(Self.failure(outcome.text)) }
        return decorated(
            Self.result(outcome.text, structured: outcome.data ?? .object([:]))
        )
    }

    /// One command's answer, as `run` and `run_batch` both report
    /// it: the one place a reply becomes a step, and the one place
    /// a change report reaches the ledger.
    func outcome(of request: CommandRequest) -> MCPOutcome {
        var request = request
        request.reportChanges = true
        let watch = ledger.watch
        request.keepWatch = watch.isEmpty ? nil : watch
        do {
            let response = try send(request)
            if let changes = response.changes { ledger.absorb(changes) }
            return MCPOutcome(
                request: request,
                ok: response.isSuccess,
                data: response.data,
                error: response.isSuccess
                    ? nil : (response.error ?? "failed")
            )
        } catch {
            return MCPOutcome(
                request: request,
                ok: false,
                data: nil,
                error: MCPWording.unanswered(error)
            )
        }
    }
}

/// One command's answer.
struct MCPOutcome {
    let request: CommandRequest
    let ok: Bool
    let data: JSONValue?
    let error: String?

    /// What the model reads: the reason, or the data.
    var text: String {
        if let error { return error }
        return data.map(MCPTools.text(of:)) ?? "ok"
    }

    var step: JSONValue {
        var fields: [String: JSONValue] = [
            "command": .string(request.command),
            "ok": .bool(ok),
        ]
        if let data { fields["data"] = data }
        if let error { fields["error"] = .string(error) }
        return .object(fields)
    }
}
