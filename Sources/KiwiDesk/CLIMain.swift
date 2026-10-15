import Foundation
import KiwiDeskCore

/// CLI mode: the same binary doubles as the command-line tool
/// when invoked with arguments (`kiwidesk focus left`).
func runCLI(_ arguments: [String]) -> Int32 {
    switch CLIRoute.of(arguments[1]) {
    case .help:
        // Answered locally from binary's APIReference (#1033).
        return CLIHelp.run(arguments)
    case .version:
        print(KiwiDeskVersion.displayString)
        return 0
    case .service:
        return runService(arguments)
    case .mcp:
        // An MCP client's stdio server (#1685), not a socket verb.
        return MCPServer.run()
    case .completion:
        return CLICompletion.run(arguments)
    case .complete:
        return CLICompleter.run(arguments)
    case .watch:
        return CLIWatch.run(arguments)
    case .socket:
        return runSocketCommand(arguments)
    }
}

/// `kiwidesk service`'s actions; completion offers them too.
enum ServiceAction: String, CaseIterable {
    case start, stop, restart, status

    static var usage: String {
        "usage: kiwidesk service "
            + allCases.map(\.rawValue).joined(separator: "|")
    }
}

private func runService(_ arguments: [String]) -> Int32 {
    guard arguments.count > 2 else {
        print(ServiceAction.usage)
        return 1
    }
    guard let action = ServiceAction(rawValue: arguments[2]) else {
        print("unknown service command: \(arguments[2])")
        return 1
    }
    let outcome: ServiceManager.Outcome
    switch action {
    case .start:
        outcome = ServiceManager.start()
    case .stop:
        outcome = ServiceManager.stop()
    case .restart:
        outcome = ServiceManager.restart()
    case .status:
        outcome = ServiceManager.status()
    }
    // Errors go to stderr with non-zero exit; status messages to
    // stdout (#328).
    if outcome.ok {
        print(outcome.message)
        // Surface independent login-item auto-start state (#575).
        printLoginItemOverlap(for: arguments[2])
    } else {
        FileHandle.standardError.write(
            Data("\(outcome.message)\n".utf8)
        )
    }
    return outcome.ok ? 0 : 1
}

/// `status` always reports the login-item half of the auto-start
/// picture; `start` adds a reassuring note only when the login item
/// is *also* on. Other verbs stay silent.
private func printLoginItemOverlap(for verb: String) {
    let state = LoginItemManager.current
    switch verb {
    case "status":
        print(LoginItemCLINote.statusLine(state))
    case "start":
        if let note = LoginItemCLINote.startNote(state) {
            print(note)
        }
    default:
        break
    }
}

private func runSocketCommand(
    _ arguments: [String]
) -> Int32 {
    let command = arguments[1]
    var rest = Array(arguments.dropFirst(2))
    var selfTestText = false
    if command == PrivatePathSelfTest.command {
        // Text on a terminal, JSON piped or with --json (#1889),
        // as `list_commands` answers.
        guard let json = CLISelfTest.parseOptions(rest) else {
            FileHandle.standardError.write(
                Data("error: \(command) takes only --json\n".utf8)
            )
            return 1
        }
        selfTestText = !json && CLIOutput.stdoutIsTerminal
        rest = []
    }
    if command == APIReference.socketOnlyCommand {
        return CLIEventStream.subscribe(rest)
    }
    let args = rest.map { JSONValue.string($0) }
    let request = CommandRequest(
        command: command,
        args: args.isEmpty ? nil : args
    )

    let client: SocketClient
    do {
        client = try AppSocket.connect()
    } catch {
        FileHandle.standardError.write(
            Data("\(cannotConnectMessage(error))\n".utf8)
        )
        return 1
    }

    do {
        let response = try client.roundTrip(request)
        if selfTestText, let data = response.data,
            let text = CLISelfTest.render(data)
        {
            print(text)
        } else if let data = response.data,
            let text = CLIOutput.render(
                data,
                pretty: CLIOutput.stdoutIsTerminal
            )
        {
            print(text)
            for note in CLIOutput.declaredInNotes(data) {
                FileHandle.standardError.write(
                    Data("\(note)\n".utf8)
                )
            }
        }
        if let error = response.error {
            FileHandle.standardError.write(
                Data("error: \(error)\n".utf8)
            )
        }
        guard response.isSuccess else { return 1 }
        return command == PrivatePathSelfTest.command
            ? CLISelfTest.exitCode(response.data) : 0
    } catch {
        FileHandle.standardError.write(
            Data("KiwiDesk: \(error)\n".utf8)
        )
        return 1
    }
}

/// The note a socket verb prints when no app answers.
func cannotConnectMessage(_ error: Error) -> String {
    """
    KiwiDesk: cannot connect to \(KiwiCore.defaultSocketPath)
    Is the KiwiDesk app running? (\(error))
    """
}

let cliUsage = """
    KiwiDesk — tiling window manager for macOS

    usage:
      kiwidesk                        run the app
      kiwidesk <command> [args...]    send an IPC command
      kiwidesk --version              print version and exit
      kiwidesk service start|stop|restart|status
      kiwidesk subscribe [--reconnect] [events...]
                                      stream events (NDJSON)
      kiwidesk watch [events...] -- <command> [args...]
                                      run a command per event
      kiwidesk completion zsh|bash|fish
                                      print a shell completion script
      kiwidesk mcp                    MCP server on stdio, for AI apps

    the API, from this binary (no running app needed):
      kiwidesk list_commands          every command, grouped
      kiwidesk help <name>            one command's arguments
      add --json to either for machine-readable output

    examples:
      kiwidesk focus left
      kiwidesk set_mode 1 bsp
      kiwidesk set_gap_global 12
      kiwidesk get_state
      kiwidesk help scroll.set_anchor
      kiwidesk subscribe space_change layout_change
      kiwidesk watch space_change -- sketchybar --trigger kiwi_space
    """
