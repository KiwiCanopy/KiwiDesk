import Foundation
import KiwiDeskCore

/// Answers `kiwidesk help [name]` and `kiwidesk list_commands [name]`
/// locally, rendering APIReference data and never re-derives it
/// (#1033, CLIHelpSeamTests).
enum CLIHelp {
    /// Verbs answered by local CLI help.
    static let verbs: Set<String> = [
        "help", "--help", "-h", "list_commands",
    ]

    /// The one option these verbs take.
    static let jsonFlag = "--json"

    /// Runs a help invocation. `arguments` is the full process
    /// argument list.
    static func run(_ arguments: [String]) -> Int32 {
        let verb = arguments[1]
        let rest = arguments.dropFirst(2).map { $0 }
        let wantsJSON = rest.contains(jsonFlag)
        let topic = rest.first { !$0.hasPrefix("-") }

        // Reject unknown flags explicitly.
        let unknown = rest.filter {
            $0.hasPrefix("-") && $0 != jsonFlag
        }
        if let flag = unknown.first {
            FileHandle.standardError.write(
                Data("unknown option: \(flag)\n".utf8)
            )
            return 1
        }

        // Print usage block when invoked without topic or JSON flag.
        if topic == nil, !wantsJSON, verb != "list_commands" {
            print(cliUsage)
            return 0
        }

        let response = APIReference.helpResponse(for: topic)
        guard response.isSuccess, let data = response.data else {
            FileHandle.standardError.write(
                Data(
                    "error: \(response.error ?? "no answer")\n"
                        .utf8
                )
            )
            return 1
        }
        print(rendered(data, topic: topic, json: wantsJSON))
        return 0
    }

    /// Returns formatted help string, using JSON for pipes or explicit flag.
    private static func rendered(
        _ data: JSONValue,
        topic: String?,
        json: Bool
    ) -> String {
        let asJSON = json || !CLIOutput.stdoutIsTerminal
        if asJSON {
            // Pretty-print JSON for terminal; compact for pipes (#1035).
            return CLIOutput.render(
                data,
                pretty: CLIOutput.stdoutIsTerminal
            ) ?? ""
        }
        if let topic, let entry = APIReference.entry(named: topic) {
            return CLIHelpText.detail(of: entry)
        }
        return CLIHelpText.listing(of: APIReference.groups)
    }
}
