import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk subscribe` and its `--reconnect` (#1685 ▸ Ruling 6e):
/// without the flag a stream ends with the app; with it the stream
/// waits, re-subscribes and says on stderr what it missed.
@Suite("CLI event stream")
struct CLIEventStreamTests {
    /// One connection's worth of lines, then EOF.
    final class FakeSource: CLILineSource {
        var sent: [CommandRequest] = []
        var lines: [String]
        init(_ lines: [String]) { self.lines = lines }
        func send(_ request: CommandRequest) throws { sent.append(request) }
        func readLine() throws -> String? {
            lines.isEmpty ? nil : lines.removeFirst()
        }
    }

    struct Refused: Error {}

    /// A script of connection attempts: a source, or a refusal.
    final class Script {
        var attempts: [FakeSource?]
        var sources: [FakeSource] = []
        var notes: [String] = []
        var delivered: [String] = []
        var pauses = 0
        init(_ attempts: [FakeSource?]) { self.attempts = attempts }

        var stream: CLIEventStream {
            var stream = CLIEventStream()
            stream.connect = { [self] in
                guard let source = attempts.removeFirst() else {
                    throw Refused()
                }
                sources.append(source)
                return source
            }
            stream.pause = { [self] in pauses += 1 }
            stream.note = { [self] in notes.append($0) }
            stream.keepGoing = { [self] in !attempts.isEmpty }
            return stream
        }

        func run(_ events: [String], reconnect: Bool) -> Int32 {
            stream.run(events: events, reconnect: reconnect) {
                delivered.append($0)
            }
        }
    }

    static let ack = #"{"status":"success"}"#
    static let event = #"{"event":"space_change","data":{}}"#

    @Test("without the flag the stream ends with the app")
    func endsWithTheApp() {
        let script = Script([
            FakeSource([Self.ack, Self.event]), FakeSource([Self.ack]),
        ])
        #expect(script.run(["space_change"], reconnect: false) == 0)
        #expect(script.delivered == [Self.ack, Self.event])
        #expect(script.sources.count == 1, "reconnected unasked")
        #expect(script.notes.isEmpty)
        let sent = script.sources[0].sent
        #expect(sent.map(\.command) == ["subscribe"])
        #expect(sent.first?.args == [.string("space_change")])
    }

    @Test("without the flag an unreachable app is an error")
    func unreachableFails() {
        let script = Script([nil, FakeSource([])])
        #expect(script.run([], reconnect: false) == 1)
        #expect(script.notes.count == 1)
        #expect(script.notes.first?.contains("cannot connect") == true)
        #expect(script.pauses == 0)
    }

    @Test("with the flag the stream re-subscribes and reports the gap")
    func reconnects() {
        let script = Script([
            FakeSource([Self.ack, Self.event]),
            nil,
            nil,
            FakeSource([Self.ack, Self.event]),
        ])
        _ = script.run(["space_change"], reconnect: true)
        #expect(
            script.delivered == [
                Self.ack, Self.event, Self.ack, Self.event,
            ]
        )
        #expect(
            script.sources.map { $0.sent.first?.args }
                == [[.string("space_change")], [.string("space_change")]],
            "the second subscription lost its filter"
        )
        let notes = script.notes
        #expect(notes.count == 3, "\(notes)")
        #expect(notes.first?.contains("went away") == true)
        #expect(notes.dropFirst().first?.contains("missed") == true)
        #expect(script.pauses == 4)
    }

    @Test("with the flag the first connect waits, noted once")
    func waitsForTheApp() {
        let script = Script([nil, nil, FakeSource([Self.ack])])
        _ = script.run([], reconnect: true)
        #expect(script.delivered == [Self.ack])
        #expect(script.notes.count == 2, "\(script.notes)")
        #expect(script.notes.first?.contains("waiting") == true)
        #expect(script.sources.first?.sent.first?.args == nil)
    }

    @Test("a connection that answers nothing is not a reconnect")
    func silentConnectionIsNoGap() {
        let script = Script([
            FakeSource([Self.ack]), FakeSource([]), FakeSource([]),
        ])
        _ = script.run([], reconnect: true)
        #expect(script.notes.count == 1, "\(script.notes)")
    }

    @Test("subscribe strips the flag before the names reach the app")
    func flagIsStripped() {
        let parsed = CLIEventStream.parse(
            ["focus_change", "--reconnect", "space_change"]
        )
        #expect(parsed.events == ["focus_change", "space_change"])
        #expect(parsed.reconnect)
        #expect(!CLIEventStream.parse(["focus_change"]).reconnect)
    }

    @Test("subscribe hands the parsed flag and names to its stream")
    func subscribeWiring() {
        let once = Script([FakeSource([]), FakeSource([])])
        _ = CLIEventStream.subscribe(["focus_change"], stream: once.stream)
        #expect(once.sources.count == 1, "reconnected without the flag")
        let kept = Script([FakeSource([]), FakeSource([])])
        _ = CLIEventStream.subscribe(
            ["focus_change", CLIEventStream.reconnectFlag],
            stream: kept.stream
        )
        #expect(kept.sources.count == 2, "--reconnect did not reconnect")
        #expect(
            kept.sources.first?.sent.first?.args == [.string("focus_change")]
        )
    }

    @Test("watch always reconnects and runs each event")
    func watchWiring() {
        let script = Script([
            FakeSource([Self.ack, Self.event]), FakeSource([Self.event]),
        ])
        final class Runs: @unchecked Sendable { var lines: [String] = [] }
        let runs = Runs()
        var runner = CLIWatchRunner(command: ["x"])
        runner.spawn = { _, _, line in
            runs.lines.append(line)
            return 0
        }
        runner.note = { _ in }
        let code = CLIWatch.watch(
            .init(events: ["space_change"], command: ["x"]),
            stream: script.stream,
            runner: runner
        )
        #expect(code == 0)
        #expect(script.sources.count == 2, "watch did not reconnect")
        #expect(runs.lines == [Self.event, Self.event])
    }
}
