import Foundation
import Testing

@testable import KiwiDesk

/// `kiwidesk completion` (#1685 ▸ Ruling 6e): each shim asks
/// `__complete` under the name the user typed, honours the default
/// directive, and names no command itself — so it cannot go stale.
@Suite("CLI completion shims")
struct CLICompletionTests {
    @Test("the usage names every shell a shim exists for")
    func everyShell() {
        for shell in CLICompletion.Shell.allCases {
            #expect(CLICompletion.usage.contains(shell.rawValue))
        }
    }

    /// How each shim unquotes the word it asks about; bash's is
    /// driven for real in `ExecTestsCLICompletion`.
    static let unquotes = [
        "zsh": "(@Q)",
        "bash": #"${typed//\\/}"#,
        "fish": "string unescape",
    ]

    @Test("each shim asks __complete and honours the directive")
    func shimsAsk() throws {
        let typed = [
            "zsh": #""${words[1]}""#,
            "bash": #""${COMP_WORDS[0]}""#,
            "fish": "$tokens[1]",
        ]
        for shell in CLICompletion.Shell.allCases {
            let script = shell.script
            let caller = try #require(typed[shell.rawValue])
            #expect(
                script.contains("\(caller) \(CLICompleter.verb)"),
                "\(shell) must call the binary the user typed"
            )
            #expect(
                script.contains(CLICompleter.defaultDirective),
                "\(shell) ignores the default directive"
            )
            #expect(
                script.contains(Self.unquotes[shell.rawValue] ?? "?"),
                "\(shell) sends the typed word with its quoting"
            )
            for command in ["focus_space", "subscribe", "load_profile"] {
                #expect(!script.contains(command), "\(shell): \(command)")
            }
        }
    }
}
