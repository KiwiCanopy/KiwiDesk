import Foundation
import KiwiDeskCore

/// CLI mode: the same binary doubles as the command-line tool
/// when invoked with arguments (`kiwidesk focus left`).
func runCLI(_ arguments: [String]) -> Int32 {
    let command = arguments[1]

    switch command {
    case let help where CLIHelp.verbs.contains(help):
        // Answered from this binary's own `APIReference`, so
        // `kiwidesk help focus` works whether or not the app is
        // running (#1033) — `CLIHelp` argues the ruling.
        return CLIHelp.run(arguments)
    case "--version", "-v":
        print(KiwiDeskVersion.displayString)
        return 0
    case "service":
        return runService(arguments)
    default:
        return runSocketCommand(arguments)
    }
}

private func runService(_ arguments: [String]) -> Int32 {
    guard arguments.count > 2 else {
        print("usage: kiwidesk service start|stop|restart|status")
        return 1
    }
    let outcome: ServiceManager.Outcome
    switch arguments[2] {
    case "start":
        outcome = ServiceManager.start()
    case "stop":
        outcome = ServiceManager.stop()
    case "restart":
        outcome = ServiceManager.restart()
    case "status":
        outcome = ServiceManager.status()
    default:
        print("unknown service command: \(arguments[2])")
        return 1
    }
    // Real launchctl failures exit non-zero and go to stderr per
    // the CLI's stream contract (message on stderr, data on
    // stdout); the ordinary already-running / not-running cases
    // stay 0 on stdout (#328).
    if outcome.ok {
        print(outcome.message)
        // The login item is a second, independent auto-start path
        // (#575). Surface the overlap here — the CLI is the
        // composition root that knows both verbs, so the two Core
        // subsystems stay decoupled (`ServiceManager` never learns
        // about `SMAppService`).
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
    let args = arguments.dropFirst(2).map {
        JSONValue.string($0)
    }
    let request = CommandRequest(
        command: command,
        args: args.isEmpty ? nil : args
    )

    let client: SocketClient
    do {
        client = try SocketClient(
            path: KiwiCore.defaultSocketPath
        )
    } catch {
        FileHandle.standardError.write(
            Data(
                """
                KiwiDesk: cannot connect to \
                \(KiwiCore.defaultSocketPath)
                Is the KiwiDesk app running? (\(error))\n
                """.utf8
            )
        )
        return 1
    }

    do {
        if command == "subscribe" {
            // Stream mode: print events until killed.
            try client.send(request)
            while let line = try client.readLine() {
                print(line)
            }
            return 0
        }
        let response = try client.roundTrip(request)
        if let data = response.data,
            let text = CLIOutput.render(
                data,
                pretty: CLIOutput.stdoutIsTerminal
            )
        {
            print(text)
        }
        if let error = response.error {
            FileHandle.standardError.write(
                Data("error: \(error)\n".utf8)
            )
        }
        return response.isSuccess ? 0 : 1
    } catch {
        FileHandle.standardError.write(
            Data("KiwiDesk: \(error)\n".utf8)
        )
        return 1
    }
}

let cliUsage = """
    KiwiDesk — tiling window manager for macOS

    usage:
      kiwidesk                        run the app
      kiwidesk <command> [args...]    send an IPC command
      kiwidesk --version              print version and exit
      kiwidesk service start|stop|restart|status
      kiwidesk subscribe [events...]  stream events (NDJSON)

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
    """
