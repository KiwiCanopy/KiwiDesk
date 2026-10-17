import Foundation

/// Where `runCLI` sends a first argument: one of the verbs this
/// binary answers without the app, or the socket. The verbs are
/// the one register of local verbs (#1685 ▸ Ruling 6e) — the
/// dispatch and shell completion both read it, so a verb added
/// here is routed and completed alike.
enum CLIRoute: CaseIterable, Equatable {
    case help
    case version
    case service
    case mcp
    case completion
    case complete
    case watch
    case socket

    /// The spellings that select this route. The socket takes
    /// every other first argument, so it lists none.
    var verbs: [String] {
        switch self {
        case .help: return CLIHelp.verbs.sorted()
        case .version: return ["--version", "-v"]
        case .service: return ["service"]
        case .mcp: return [MCPInvocation.verb]
        case .completion: return [CLICompletion.verb]
        case .complete: return [CLICompleter.verb]
        case .watch: return [CLIWatch.verb]
        case .socket: return []
        }
    }

    /// The route a first argument takes.
    static func of(_ verb: String) -> CLIRoute {
        allCases.first { $0.verbs.contains(verb) } ?? .socket
    }

    /// Whether completion offers this route's verbs; the hidden
    /// `__complete` is the shims' alone.
    var offered: Bool { self != .complete }

    /// Every local verb, in route order.
    static var localVerbs: [String] { allCases.flatMap(\.verbs) }

    /// The local verbs completion offers.
    static var offeredVerbs: [String] {
        allCases.filter(\.offered).flatMap(\.verbs)
    }

    /// Local verbs that answer a name the API also lists, by
    /// ruling: help is answered from the binary (#1033). Any other
    /// overlap would hide a socket command (`CLIRouteTests`).
    static let shadowedCommands: Set<String> = ["help"]
}
