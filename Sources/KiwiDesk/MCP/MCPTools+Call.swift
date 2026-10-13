import Foundation
import KiwiDeskCore

/// `tools/call` (#1685). A malformed call is a protocol error; a
/// command KiwiDesk refuses is a tool result with `isError`, so
/// the model can read the reason and correct itself.
extension MCPTools {
    func call(_ params: [String: JSONValue]) throws -> JSONValue {
        guard let name = params["name"]?.stringValue else {
            throw MCPFailure(.invalidParams, "tools/call needs a name")
        }
        var arguments: [String: JSONValue] = [:]
        if case .object(let given)? = params["arguments"] {
            arguments = given
        }
        switch name {
        case Self.listCommands:
            return listing(filter: arguments["filter"]?.stringValue)
        case Self.help:
            return help(arguments["name"]?.stringValue)
        case Self.getState:
            return forward(CommandRequest(command: "get_state"))
        case Self.run:
            return runOne(arguments, destructive: false)
        case Self.runDestructive:
            return runOne(arguments, destructive: true)
        case Self.runBatch:
            return runBatch(arguments["commands"])
        default:
            throw MCPFailure(.invalidParams, "unknown tool: \(name)")
        }
    }

    // MARK: - Reads answered from this binary

    private func listing(filter: String?) -> JSONValue {
        let needle = filter?.lowercased() ?? ""
        let rows = APIReference.groups.flatMap(\.entries).filter {
            Self.isRunnable($0)
        }.filter { entry in
            needle.isEmpty
                || [entry.qualifiedName, entry.group, entry.record.summary]
                    .contains { $0.lowercased().contains(needle) }
        }
        let lines = rows.map { entry in
            let mark = Self.isDestructive(entry) ? " [destructive]" : ""
            return "\(entry.qualifiedName) — \(entry.record.summary)\(mark)"
        }
        let text =
            lines.isEmpty
            ? "No command matches \"\(filter ?? "")\"."
            : lines.joined(separator: "\n")
        return Self.result(
            text,
            structured: .object([
                "commands": .array(
                    rows.map { entry -> JSONValue in
                        .object([
                            "name": .string(entry.qualifiedName),
                            "summary": .string(entry.record.summary),
                            "destructive": .bool(Self.isDestructive(entry)),
                        ])
                    }
                )
            ])
        )
    }

    private func help(_ name: String?) -> JSONValue {
        guard let name, !name.isEmpty else {
            return Self.failure("help needs a command name")
        }
        let response = APIReference.helpResponse(for: name)
        guard response.isSuccess, let data = response.data else {
            return Self.failure(response.error ?? "no answer")
        }
        return Self.result(Self.text(of: data), structured: data)
    }

    // MARK: - Commands forwarded to the app

    private func runOne(
        _ arguments: [String: JSONValue],
        destructive: Bool
    ) -> JSONValue {
        let request: CommandRequest
        switch Self.request(from: arguments) {
        case .failure(let reason): return Self.failure(reason)
        case .success(let parsed): request = parsed
        }
        if let refusal = Self.refusal(of: request.command, destructive) {
            return Self.failure(refusal)
        }
        return forward(request)
    }

    private func runBatch(_ value: JSONValue?) -> JSONValue {
        guard case .array(let items)? = value, !items.isEmpty else {
            return Self.failure("run_batch needs a commands array")
        }
        guard items.count <= Self.batchLimit else {
            return Self.failure(
                "run_batch takes at most \(Self.batchLimit) commands"
            )
        }
        var requests: [CommandRequest] = []
        for (index, item) in items.enumerated() {
            guard case .object(let fields) = item else {
                return Self.failure("commands[\(index)] is not an object")
            }
            switch Self.request(from: fields) {
            case .failure(let reason):
                return Self.failure("commands[\(index)]: \(reason.reason)")
            case .success(let parsed): requests.append(parsed)
            }
        }
        // Refuse before running any, so a batch never stops halfway
        // for a reason it could have known up front.
        for request in requests {
            if let refusal = Self.refusal(of: request.command, false) {
                return Self.failure(refusal)
            }
        }
        return MCPBatch(requests: requests, send: send).run()
    }

    /// Sends one request and turns the reply into a tool result.
    func forward(_ request: CommandRequest) -> JSONValue {
        let response: CommandResponse
        do {
            response = try send(request)
        } catch {
            return Self.failure(
                "KiwiDesk is not reachable. Is the app running? "
                    + "(\(error))"
            )
        }
        guard response.isSuccess else {
            return Self.failure(response.error ?? "failed")
        }
        let data = response.data ?? .object([:])
        var text = response.data.map(Self.text(of:)) ?? "ok"
        if Self.isSetter(request.command) {
            text += "\n" + Self.temporaryNote
        }
        return Self.result(text, structured: Self.wrapped(data))
    }
}
