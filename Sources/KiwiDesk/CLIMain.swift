import Foundation
import KiwiDeskCore

/// CLI mode: the same binary doubles as the command-line tool
/// when invoked with arguments (`KiwiDesk focus left`).
func runCLI(_ arguments: [String]) -> Int32 {
    let command = arguments[1]

    switch command {
    case "help", "--help", "-h":
        print(cliUsage)
        return 0
    case "service":
        return runService(arguments)
    default:
        return runSocketCommand(arguments)
    }
}

private func runService(_ arguments: [String]) -> Int32 {
    guard arguments.count > 2 else {
        print("usage: KiwiDesk service start|stop|restart")
        return 1
    }
    switch arguments[2] {
    case "start":
        print(ServiceManager.start())
    case "stop":
        print(ServiceManager.stop())
    case "restart":
        print(ServiceManager.restart())
    default:
        print("unknown service command: \(arguments[2])")
        return 1
    }
    return 0
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
            let encoded = try? JSONEncoder().encode(data),
            let text = String(data: encoded, encoding: .utf8)
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

private let cliUsage = """
    KiwiDesk — tiling window manager for macOS

    usage:
      KiwiDesk                        run the app
      KiwiDesk <command> [args...]    send an IPC command
      KiwiDesk service start|stop|restart
      KiwiDesk subscribe [events...]  stream events (NDJSON)

    examples:
      KiwiDesk focus left
      KiwiDesk set_mode 1 bsp
      KiwiDesk set_gap_global 12
      KiwiDesk get_state
      KiwiDesk subscribe space_change layout_change

    run 'KiwiDesk list_commands' (app must be running) for
    the full command list.
    """
