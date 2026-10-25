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

    /// Forces JSON output.
    static let jsonFlag = "--json"

    /// Narrows the listing to one `APIKind`; takes its value as the
    /// next argument (#2610).
    static let kindFlag = "--kind"

    /// Runs a help invocation. `arguments` is the full process
    /// argument list.
    static func run(_ arguments: [String]) -> Int32 {
        let verb = arguments[1]
        var rest = arguments.dropFirst(2).map { $0 }
        let kind: APIKind?
        switch takeKind(from: &rest) {
        case .success(let taken): kind = taken
        case .failure(let refusal): return fail(refusal.message)
        }
        let wantsJSON = rest.contains(jsonFlag)
        let topic = rest.first { !$0.hasPrefix("-") }

        // Reject unknown flags explicitly.
        let unknown = rest.filter {
            $0.hasPrefix("-") && $0 != jsonFlag
        }
        if let flag = unknown.first {
            return fail("unknown option: \(flag)")
        }
        if kind != nil, topic != nil {
            return fail("\(kindFlag) lists commands; it takes no name")
        }

        // Print usage block when invoked without topic or JSON flag.
        if topic == nil, kind == nil, !wantsJSON,
            verb != "list_commands"
        {
            print(cliUsage)
            return 0
        }

        let response = APIReference.helpResponse(for: topic, kind: kind)
        guard response.isSuccess, let data = response.data else {
            return fail("error: \(response.error ?? "no answer")")
        }
        print(rendered(data, topic: topic, kind: kind, json: wantsJSON))
        return 0
    }

    /// A refused `--kind`, worded for stderr.
    struct KindRefusal: Error { let message: String }

    /// Removes `--kind <value>` from `rest` and parses the value;
    /// nil where the flag is absent.
    static func takeKind(
        from rest: inout [String]
    ) -> Result<APIKind?, KindRefusal> {
        guard let at = rest.firstIndex(of: kindFlag) else {
            return .success(nil)
        }
        let kinds = APIKind.allCases.map(\.rawValue)
            .joined(separator: "|")
        guard at + 1 < rest.endIndex else {
            return .failure(
                KindRefusal(
                    message: "\(kindFlag) needs a value: \(kinds)"
                )
            )
        }
        let value = rest[at + 1]
        rest.removeSubrange(at...(at + 1))
        guard let kind = APIKind(rawValue: value) else {
            return .failure(
                KindRefusal(
                    message: "unknown kind: \(value) (expected \(kinds))"
                )
            )
        }
        return .success(kind)
    }

    private static func fail(_ message: String) -> Int32 {
        FileHandle.standardError.write(Data("\(message)\n".utf8))
        return 1
    }

    /// Returns formatted help string, using JSON for pipes or explicit flag.
    private static func rendered(
        _ data: JSONValue,
        topic: String?,
        kind: APIKind?,
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
        return CLIHelpText.listing(of: APIReference.groups(of: kind))
    }
}
