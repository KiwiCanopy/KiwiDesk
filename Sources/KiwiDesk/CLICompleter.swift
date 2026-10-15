import Foundation
import KiwiDeskCore

/// `kiwidesk __complete <words…> <current>`: the candidates a shell
/// completion shim offers, one per line (#1685 ▸ Ruling 6e). Read
/// from this binary's `APIReference`, so an upgrade never leaves
/// the completion stale; live names come from the running app.
struct CLICompleter {
    static let verb = "__complete"

    /// Printed alone when the shell should complete as it would
    /// for any command — the program a `watch` runs, say.
    static let defaultDirective = ":default"

    var live = CLILiveValues()

    /// What to offer for `current`, given the words before it.
    enum Answer: Equatable {
        case candidates([String])
        case shellDefault
    }

    func answer(words: [String], current: String) -> Answer {
        guard let first = words.first else {
            return .candidates(Self.firstWords(current))
        }
        let rest = Array(words.dropFirst())
        let offer: [String]
        switch CLIRoute.of(first) {
        case .help:
            offer = rest.isEmpty ? Self.commandNames + [CLIHelp.jsonFlag] : []
        case .service:
            offer = rest.isEmpty ? ServiceAction.allCases.map(\.rawValue) : []
        case .completion:
            offer =
                rest.isEmpty
                ? CLICompletion.Shell.allCases.map(\.rawValue) : []
        case .watch:
            if rest.contains(CLIWatch.separator) { return .shellDefault }
            offer =
                Self.events.filter { !rest.contains($0) }
                + [CLIWatch.separator]
        case .socket:
            offer = socketCandidates(first, rest)
        case .version, .mcp, .complete:
            offer = []
        }
        return .candidates(offer.filter { $0.hasPrefix(current) })
    }

    /// A command's next argument: its record's values, or the live
    /// names its kind or `CLILiveValues.textSources` names.
    private func socketCandidates(
        _ command: String,
        _ rest: [String]
    ) -> [String] {
        if command == APIReference.socketOnlyCommand {
            return (Self.events + [CLIEventStream.reconnectFlag])
                .filter { !rest.contains($0) }
        }
        guard
            let entry = APIReference.entry(named: command),
            entry.channel != .lua,
            rest.count < entry.record.arguments.count
        else { return [] }
        let argument = entry.record.arguments[rest.count]
        switch argument.kind {
        case .choice(let choice):
            return choice.values
        case .boolean:
            return ["true", "false"]
        case .space:
            return live.names(.spaces)
        case .window:
            return live.names(.windows)
        case .text:
            let source = CLILiveValues.textSources[
                entry.qualifiedName
            ]?[argument.name]
            return source.map(live.names) ?? []
        default:
            return []
        }
    }

    /// The first word: every local verb a user types — a flag only
    /// once `-` is typed — then every command the CLI can send.
    private static func firstWords(_ current: String) -> [String] {
        let local = CLIRoute.offeredVerbs.filter {
            $0.hasPrefix("-") == current.hasPrefix("-")
        }
        let commands = commandNames.filter { !local.contains($0) }
        return (local + commands).filter { $0.hasPrefix(current) }
    }

    /// Every command the socket answers, as `list_commands` names
    /// them.
    static var commandNames: [String] {
        APIReference.groups.flatMap(\.entries)
            .filter { $0.channel != .lua }
            .map(\.qualifiedName)
    }

    /// The event names, read off `subscribe`'s own record.
    static var events: [String] {
        guard
            let argument = APIReference.entry(
                named: APIReference.socketOnlyCommand
            )?.record.arguments.first,
            case .choice(let choice) = argument.kind
        else { return [] }
        return choice.values
    }

    /// `kiwidesk __complete …`: the last argument is the word being
    /// completed, empty when the cursor starts a new one.
    static func run(_ arguments: [String]) -> Int32 {
        let words = Array(arguments.dropFirst(2))
        let current = words.last ?? ""
        let answer = CLICompleter().answer(
            words: Array(words.dropLast()),
            current: current
        )
        switch answer {
        case .shellDefault:
            print(defaultDirective)
        case .candidates(let candidates):
            for candidate in candidates { print(candidate) }
        }
        return 0
    }
}
