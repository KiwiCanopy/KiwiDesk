import Foundation
import Testing

@testable import KiwiDesk

/// `kiwidesk completion` (#1685 ▸ Ruling 6e): each shim asks
/// `__complete` under the name the user typed, honours the default
/// directive, and names no command itself — so it cannot go stale.
@Suite("CLI completion shims")
struct CLICompletionTests {
    @Test("every shell the completer offers has a shim")
    func everyShell() {
        for shell in CLICompleter.shells {
            #expect(CLICompletion.script(for: shell) != nil, "\(shell)")
        }
        #expect(CLICompletion.script(for: "tcsh") == nil)
    }

    @Test("each shim asks __complete and honours the directive")
    func shimsAsk() throws {
        let typed = [
            "zsh": #""${words[1]}""#,
            "bash": #""${COMP_WORDS[0]}""#,
            "fish": "$tokens[1]",
        ]
        for shell in CLICompleter.shells {
            let script = try #require(CLICompletion.script(for: shell))
            let caller = try #require(typed[shell])
            #expect(
                script.contains("\(caller) \(CLICompleter.verb)"),
                "\(shell) must call the binary the user typed"
            )
            #expect(
                script.contains(CLICompleter.defaultDirective),
                "\(shell) ignores the default directive"
            )
            for command in ["focus_space", "subscribe", "load_profile"] {
                #expect(!script.contains(command), "\(shell): \(command)")
            }
        }
    }
}
