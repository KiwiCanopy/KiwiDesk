import Foundation
import KiwiDeskCore

/// `kiwidesk help [name]` and `kiwidesk list_commands [name]`
/// (#1033).
///
/// **These two are answered locally, not over the socket**, and
/// that is the ruling the issue asked for. The listing describes
/// the API surface a binary was built with — static data, no app
/// state in it — and `APIReference` is compiled into this same
/// binary, so a round trip would buy nothing and would make
/// `kiwidesk help focus` fail exactly when a user reaches for it:
/// while the app is not running. `--version` is answered the same
/// way for the same reason.
///
/// The cost is honest and worth naming: if an older KiwiDesk is
/// running while a newer `kiwidesk` is on `$PATH`, the listing
/// describes the newer one. They ship as one binary, so that is
/// a mismatched install rather than a mode of operation.
///
/// The listing itself comes from `APIReference.helpResponse`,
/// the same function the dispatcher's `help` case returns — this
/// renders it, and never re-derives it (`CLIHelpSeamTests`).
enum CLIHelp {
    /// The verbs this answers. `help` also arrives spelled as a
    /// flag, which is how a CLI user asks the same question.
    static let verbs: Set<String> = [
        "help", "--help", "-h", "list_commands",
    ]

    /// Runs a help invocation. `arguments` is the full process
    /// argument list.
    static func run(_ arguments: [String]) -> Int32 {
        let verb = arguments[1]
        let rest = arguments.dropFirst(2).map { $0 }
        let wantsJSON = rest.contains("--json")
        let topic = rest.first { !$0.hasPrefix("-") }

        // No topic and no `--json` on the front-door spelling:
        // the usage block, which is what a bare `kiwidesk help`
        // has always printed and what a first-time reader wants.
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

    /// JSON when asked for it or when stdout is not a terminal —
    /// a pipe is a script, and scripts already parse this
    /// command's JSON. A terminal gets the grouped text.
    private static func rendered(
        _ data: JSONValue,
        topic: String?,
        json: Bool
    ) -> String {
        let asJSON = json || !CLIOutput.stdoutIsTerminal
        if asJSON {
            // Pretty on a terminal only, as #1035 ruled: a pipe
            // keeps the compact line scripts already parse.
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
