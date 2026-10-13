import Foundation
import KiwiDeskCore

/// `run_batch`'s run (#1685): the commands in order, stopping at
/// the first one KiwiDesk refuses or cannot be reached for, so a
/// later command never acts on a state the failed one left half
/// made.
struct MCPBatch {
    let requests: [CommandRequest]
    let send: (CommandRequest) throws -> CommandResponse

    func run() -> JSONValue {
        var steps: [JSONValue] = []
        var lines: [String] = []
        var stopped: String?
        var changed = false
        for request in requests {
            var step: [String: JSONValue] = [
                "command": .string(request.command)
            ]
            let outcome: CommandResponse
            do {
                outcome = try send(request)
            } catch {
                stopped =
                    "KiwiDesk is not reachable. Is the app "
                    + "running? (\(error))"
                step["ok"] = .bool(false)
                step["error"] = .string(stopped ?? "")
                steps.append(.object(step))
                break
            }
            step["ok"] = .bool(outcome.isSuccess)
            if let data = outcome.data { step["data"] = data }
            guard outcome.isSuccess else {
                let reason = outcome.error ?? "failed"
                step["error"] = .string(reason)
                steps.append(.object(step))
                stopped = "\(request.command) failed: \(reason)"
                break
            }
            changed = changed || MCPTools.isSetter(request.command)
            steps.append(.object(step))
            lines.append("\(request.command): ok")
        }
        if let stopped {
            lines.append(stopped)
            let skipped = requests.count - steps.count
            if skipped > 0 { lines.append("Not run: \(skipped).") }
        }
        if changed { lines.append(MCPTools.temporaryNote) }
        let structured = JSONValue.object([
            "results": .array(steps),
            "completed": .number(
                Double(steps.count - (stopped == nil ? 0 : 1))
            ),
        ])
        let text = lines.joined(separator: "\n")
        guard stopped == nil else {
            var failure = MCPTools.failure(text)
            if case .object(var fields) = failure {
                fields["structuredContent"] = structured
                failure = .object(fields)
            }
            return failure
        }
        return MCPTools.result(text, structured: structured)
    }
}
