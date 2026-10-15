import Foundation
import KiwiDeskCore

/// What the event stream reads from: the app's socket, or a test's
/// fake.
protocol CLILineSource: AnyObject {
    func send(_ request: CommandRequest) throws
    func readLine() throws -> String?
}

extension SocketClient: CLILineSource {}

/// `kiwidesk subscribe` and `kiwidesk watch`'s stream: every line
/// the app sends, and with `reconnect` a stream that survives a
/// relaunch (#1685 ▸ Ruling 6e). Notes go to stderr, so stdout
/// carries only the app's lines.
struct CLIEventStream {
    /// The flag that keeps a `subscribe` across a relaunch.
    static let reconnectFlag = "--reconnect"

    /// Wait between connection attempts, in seconds.
    static let retryInterval: TimeInterval = 0.5

    var connect: () throws -> CLILineSource = { try AppSocket.connect() }
    var pause: () -> Void = {
        Thread.sleep(forTimeInterval: CLIEventStream.retryInterval)
    }
    var note: (String) -> Void = CLIEventStream.writeNote
    /// Asked before each attempt; a test ends the loop with it.
    var keepGoing: () -> Bool = { true }

    /// Streams the app's lines to `deliver`. Without `reconnect`
    /// it ends when the app goes away (0) or cannot be reached
    /// (1); with it, it waits and re-subscribes until killed.
    func run(
        events: [String],
        reconnect: Bool,
        deliver: (String) -> Void
    ) -> Int32 {
        let request = CommandRequest(
            command: APIReference.socketOnlyCommand,
            args: events.isEmpty ? nil : events.map(JSONValue.string)
        )
        var waitNoted = false
        var gapOpen = false
        while keepGoing() {
            let source: CLILineSource
            do {
                source = try connect()
            } catch {
                guard reconnect else {
                    note(cannotConnectMessage(error))
                    return 1
                }
                if !waitNoted && !gapOpen {
                    note("kiwidesk: waiting for KiwiDesk…")
                    waitNoted = true
                }
                pause()
                continue
            }
            var delivered = false
            do {
                try source.send(request)
                while let line = try source.readLine() {
                    if gapOpen {
                        note(
                            "kiwidesk: reconnected; events in between "
                                + "were missed"
                        )
                        gapOpen = false
                    }
                    delivered = true
                    deliver(line)
                }
            } catch {
                guard reconnect else {
                    note("KiwiDesk: \(error)")
                    return 1
                }
            }
            guard reconnect else { return 0 }
            if delivered && !gapOpen {
                note("kiwidesk: KiwiDesk went away; reconnecting…")
                gapOpen = true
            }
            pause()
        }
        return 0
    }

    /// `kiwidesk subscribe [--reconnect] [events…]`.
    static func subscribe(
        _ rest: [String],
        stream: CLIEventStream = CLIEventStream()
    ) -> Int32 {
        let parsed = parse(rest)
        return stream.run(
            events: parsed.events,
            reconnect: parsed.reconnect,
            deliver: writeLine
        )
    }

    /// The event names and the flag, which never reaches the app
    /// as a name.
    static func parse(
        _ rest: [String]
    ) -> (events: [String], reconnect: Bool) {
        (rest.filter { $0 != reconnectFlag }, rest.contains(reconnectFlag))
    }

    /// Writes one note to stderr; a closed stderr drops it rather
    /// than ending the process.
    static func writeNote(_ line: String) {
        try? FileHandle.standardError.write(
            contentsOf: Data("\(line)\n".utf8)
        )
    }

    /// Writes one line to stdout unbuffered, so a pipe or a file
    /// sees each event as it arrives.
    static func writeLine(_ line: String) {
        FileHandle.standardOutput.write(Data("\(line)\n".utf8))
    }
}
