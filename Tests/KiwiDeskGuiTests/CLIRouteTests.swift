import Foundation
import Testing

@testable import KiwiDesk

/// The one register of local verbs (#1685 ▸ Ruling 6e): every verb
/// it lists is routed off the socket, and nothing else is.
@Suite("CLI route")
struct CLIRouteTests {
    @Test("every local verb has its own route, the rest go to the socket")
    func routes() {
        for route in CLIRoute.allCases where route != .socket {
            #expect(!route.verbs.isEmpty, "\(route) has no verb")
            for verb in route.verbs {
                #expect(CLIRoute.of(verb) == route, "\(verb)")
            }
        }
        #expect(CLIRoute.of("focus_space") == .socket)
        #expect(CLIRoute.of("subscribe") == .socket)
        let verbs = CLIRoute.localVerbs
        #expect(Set(verbs).count == verbs.count, "a verb is listed twice")
    }

    /// A local verb spelled like a socket command makes that
    /// command unreachable from the CLI; only the ruled overlap may.
    @Test("no local verb hides a socket command, save help by ruling")
    func noShadowing() {
        let commands = Set(CLICompleter.commandNames)
        let shadowed = Set(CLIRoute.localVerbs).intersection(commands)
        #expect(shadowed == CLIRoute.shadowedCommands)
    }
}
