import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// `kiwidesk watch` (#1685 ▸ Ruling 6e): the split at `--`, the
/// environment a command runs with, and one run per event line.
@Suite("CLI watch")
struct CLIWatchTests {
    @Test("the arguments split at --, and a command is required")
    func parse() {
        #expect(
            CLIWatch.parse(["space_change", "--", "echo", "hi"])
                == .init(events: ["space_change"], command: ["echo", "hi"])
        )
        #expect(
            CLIWatch.parse(["--", "sh", "-c", "x -- y"])
                == .init(events: [], command: ["sh", "-c", "x -- y"])
        )
        #expect(CLIWatch.parse(["space_change"]) == nil)
        #expect(CLIWatch.parse(["space_change", "--"]) == nil)
    }

    static let line =
        #"{"event":"window_created","data":{"window_id":4711,"#
        + #""app":"Ghostty","space_id":"2","bundle_id":null,"#
        + #""floating":false,"frame":{"x":1}}}"#

    @Test("the environment carries the event, the data and its scalars")
    func environment() throws {
        let event = try #require(CLIWatchEvent(line: Self.line))
        let env = event.environment
        #expect(env["KIWIDESK_EVENT"] == "window_created")
        #expect(env["KIWIDESK_WINDOW_ID"] == "4711")
        #expect(env["KIWIDESK_APP"] == "Ghostty")
        #expect(env["KIWIDESK_SPACE_ID"] == "2")
        #expect(env["KIWIDESK_FLOATING"] == "false")
        #expect(env["KIWIDESK_BUNDLE_ID"] == nil, "null is not a value")
        #expect(env["KIWIDESK_FRAME"] == nil, "an object is not a scalar")
        let data = try #require(env["KIWIDESK_DATA"])
        let decoded = try JSONDecoder().decode(
            JSONValue.self,
            from: Data(data.utf8)
        )
        #expect(decoded == .object(event.data))
    }

    @Test("the fixed names win over a data key that spells them")
    func fixedNamesWin() throws {
        let line = #"{"event":"layer_change","data":{"event":"x"}}"#
        let event = try #require(CLIWatchEvent(line: line))
        #expect(event.environment["KIWIDESK_EVENT"] == "layer_change")
        #expect(CLIWatchEvent.variable(for: "space-id") == "KIWIDESK_SPACE_ID")
    }

    @Test("a non-integral number keeps its fraction")
    func numbers() {
        #expect(CLIWatchEvent.scalar(.number(4711)) == "4711")
        #expect(CLIWatchEvent.scalar(.number(-2)) == "-2")
        #expect(CLIWatchEvent.scalar(.number(0.5)) == "0.5")
    }

    /// A runner whose spawns are recorded instead of run.
    final class Spawns: @unchecked Sendable {
        var runs: [(command: [String], env: [String: String], stdin: String)] =
            []
        var notes: [String] = []
        var status: Int32 = 0

        func runner(_ command: [String]) -> CLIWatchRunner {
            var runner = CLIWatchRunner(command: command)
            runner.spawn = { [self] command, env, line in
                runs.append((command, env, line))
                return status
            }
            runner.note = { [self] in notes.append($0) }
            return runner
        }
    }

    @Test("an event line runs the command once, with the line on stdin")
    func runsPerEvent() {
        let spawns = Spawns()
        let runner = spawns.runner(["notify", "x"])
        runner.handle(#"{"status":"success"}"#)
        runner.handle(Self.line)
        runner.handle(Self.line)
        #expect(spawns.runs.count == 2, "the confirmation ran the command")
        #expect(spawns.runs.first?.command == ["notify", "x"])
        #expect(spawns.runs.first?.stdin == Self.line)
        #expect(spawns.runs.first?.env["KIWIDESK_WINDOW_ID"] == "4711")
        #expect(spawns.runs.first?.env["PATH"] != nil, "lost the PATH")
        #expect(spawns.notes.isEmpty)
    }

    @Test("a failing command is reported and the watch goes on")
    func failureIsReported() {
        let spawns = Spawns()
        spawns.status = 3
        let runner = spawns.runner(["false"])
        runner.handle(Self.line)
        runner.handle(Self.line)
        #expect(spawns.runs.count == 2)
        #expect(spawns.notes.count == 2)
        #expect(spawns.notes.first?.contains("exited 3") == true)
    }

    @Test("names the app did not know are reported, nothing is run")
    func unknownNames() {
        let spawns = Spawns()
        spawns.runner(["x"]).handle(
            #"{"status":"success","data":{"unknown":["space_chnage"]}}"#
        )
        #expect(spawns.runs.isEmpty)
        #expect(
            spawns.notes == ["kiwidesk watch: unknown event(s) space_chnage"]
        )
    }

    @Test("the queue hands lines over in order and ends after the last")
    func queueOrder() {
        let queue = CLIWatchQueue()
        queue.push("a")
        queue.push("b")
        queue.finish(0)
        #expect(queue.pop() == "a")
        #expect(queue.pop() == "b")
        #expect(queue.pop() == nil)
    }
}
