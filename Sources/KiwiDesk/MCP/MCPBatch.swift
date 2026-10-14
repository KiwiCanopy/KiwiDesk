import Foundation
import KiwiDeskCore

/// `run_batch`'s run (#1685): the commands in order, stopping at
/// the first one KiwiDesk refuses or does not answer, so a later
/// command never acts on a state the failed one left half made.
struct MCPBatch {
    let requests: [CommandRequest]
    let tools: MCPTools

    func run() -> JSONValue {
        var outcomes: [MCPOutcome] = []
        for request in requests {
            let outcome = tools.outcome(of: request)
            outcomes.append(outcome)
            if !outcome.ok { break }
        }
        let failed = outcomes.last.flatMap { $0.ok ? nil : $0 }
        var lines = outcomes.filter(\.ok).map {
            "\($0.request.command): ok"
        }
        if let failed {
            lines.append("\(failed.request.command) failed: \(failed.text)")
            let skipped = requests.count - outcomes.count
            if skipped > 0 { lines.append("Not run: \(skipped).") }
        }
        let structured = JSONValue.object([
            "results": .array(outcomes.map(\.step)),
            "completed": .number(Double(outcomes.filter(\.ok).count)),
        ])
        let text = lines.joined(separator: "\n")
        guard failed == nil else {
            return tools.decorated(
                MCPTools.failure(text, structured: structured)
            )
        }
        return tools.decorated(MCPTools.result(text, structured: structured))
    }
}
