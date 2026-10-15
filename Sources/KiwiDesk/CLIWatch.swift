import Foundation
import KiwiDeskCore

/// `kiwidesk watch [events…] -- <command> [args…]`: runs the command
/// once per event, one run at a time and in order (#1685 ▸ Ruling
/// 6e). The command is exec'd without a shell; it reads the event
/// line on stdin and the event in its environment (`CLIWatchEvent`).
/// The stream reconnects across a relaunch.
enum CLIWatch {
    static let verb = "watch"
    static let separator = "--"

    /// The parsed invocation.
    struct Invocation: Equatable {
        let events: [String]
        let command: [String]
    }

    /// Splits the arguments after `watch` at `--`; nil when no
    /// command follows it.
    static func parse(_ rest: [String]) -> Invocation? {
        guard let split = rest.firstIndex(of: separator) else {
            return nil
        }
        let command = Array(rest[rest.index(after: split)...])
        guard !command.isEmpty else { return nil }
        return Invocation(
            events: Array(rest[..<split]),
            command: command
        )
    }

    static let usage =
        "usage: kiwidesk watch [events...] -- <command> [args...]"

    static func run(_ arguments: [String]) -> Int32 {
        guard let invocation = parse(Array(arguments.dropFirst(2)))
        else {
            FileHandle.standardError.write(Data("\(usage)\n".utf8))
            return 1
        }
        // A command that exits without reading its stdin must end
        // the write with an error, never the watcher with a signal.
        signal(SIGPIPE, SIG_IGN)
        return watch(
            invocation,
            stream: CLIEventStream(),
            runner: CLIWatchRunner(command: invocation.command)
        )
    }

    /// Reads `stream` on its own thread — always reconnecting — and
    /// hands each line to `runner` in order, until the stream ends.
    static func watch(
        _ invocation: Invocation,
        stream: CLIEventStream,
        runner: CLIWatchRunner
    ) -> Int32 {
        let queue = CLIWatchQueue()
        let reader = StreamReader(stream: stream)
        let thread = Thread {
            let code = reader.stream.run(
                events: invocation.events,
                reconnect: true,
                deliver: queue.push
            )
            queue.finish(code)
        }
        thread.start()
        while let line = queue.pop() {
            runner.handle(line)
        }
        return queue.exitCode
    }

    /// Carries the stream onto the reader thread, which alone uses
    /// it.
    private final class StreamReader: @unchecked Sendable {
        let stream: CLIEventStream
        init(stream: CLIEventStream) { self.stream = stream }
    }
}

/// The lines the stream has read and the runner has not yet taken.
/// The reader fills it while a command runs, so the app is never
/// left holding a slow watcher's backlog.
final class CLIWatchQueue: @unchecked Sendable {
    private let lock = NSCondition()
    private var lines: [String] = []
    private var finished = false
    private(set) var exitCode: Int32 = 0

    func push(_ line: String) {
        lock.lock()
        lines.append(line)
        lock.signal()
        lock.unlock()
    }

    func finish(_ code: Int32) {
        lock.lock()
        finished = true
        exitCode = code
        lock.signal()
        lock.unlock()
    }

    /// The next line, waiting for one; nil once the stream ended
    /// and every line was taken.
    func pop() -> String? {
        lock.lock()
        defer { lock.unlock() }
        while lines.isEmpty && !finished { lock.wait() }
        return lines.isEmpty ? nil : lines.removeFirst()
    }
}

/// Runs the command for each event line; any other line — the
/// stream's confirmation — only reports names the app did not know.
struct CLIWatchRunner {
    let command: [String]
    var spawn: ([String], [String: String], String) -> Int32 =
        CLIWatchRunner.launch
    var note: (String) -> Void = CLIEventStream.writeNote

    func handle(_ line: String) {
        guard let parsed = CLIWatchEvent(line: line) else {
            if let unknown = CLIWatchEvent.unknownNames(in: line) {
                note("kiwidesk watch: unknown event(s) \(unknown)")
            }
            return
        }
        let environment = ProcessInfo.processInfo.environment
            .merging(parsed.environment) { _, new in new }
        let status = spawn(command, environment, line)
        if status != 0 {
            note(
                "kiwidesk watch: \(command[0]) exited \(status) "
                    + "on \(parsed.name)"
            )
        }
    }

    /// Runs `command` through `/usr/bin/env`, which searches the
    /// PATH, with `line` on its stdin, and waits for it.
    static func launch(
        _ command: [String],
        _ environment: [String: String],
        _ line: String
    ) -> Int32 {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = command
        process.environment = environment
        let input = Pipe()
        process.standardInput = input
        do {
            try process.run()
        } catch {
            return 127
        }
        try? input.fileHandleForWriting.write(
            contentsOf: Data("\(line)\n".utf8)
        )
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()
        return process.terminationStatus
    }
}
