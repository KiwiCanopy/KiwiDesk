import Foundation
import Testing

@testable import KiwiDeskCore

/// `run_shortcut` (#3526): the argv launch, the list read, and the
/// verb's answers. The tool is `/bin/echo` where a run must happen,
/// so `echo list` reads back as one shortcut named `list` and
/// `echo run …` succeeds; no test reaches the host's Shortcuts.
/// Waits await `ExecLauncher.untilIdle()` (tests.md ▸ Async tests).
@Suite("Apple Shortcuts", .serialized)
@MainActor
struct ExecTestsAppleShortcuts {
    @Test("an argv launch passes each argument whole, no shell")
    func argvIsLiteral() async {
        let exec = makeTestCore().exec
        var out = ""
        exec.launch(argv: "/bin/echo", ["a  b", "c\"d", "$HOME"]) {
            _,
            stdout,
            _ in out = stdout
        }
        await exec.untilIdle()
        #expect(out == "a  b c\"d $HOME\n")
    }

    @Test("an argv launch dedups on its whole argument list")
    func argvDedups() async {
        let exec = makeTestCore().exec
        exec.onLog = { _ in }
        let first = exec.launch(argv: "/bin/sleep", ["0.2"], dedup: true)
        let second = exec.launch(argv: "/bin/sleep", ["0.2"], dedup: true)
        let other = exec.launch(argv: "/bin/sleep", ["0.1"], dedup: true)
        #expect(first != nil)
        #expect(second == nil)
        #expect(other != nil)
        #expect(exec.isRunning(argv: "/bin/sleep", ["0.2"]))
        await exec.untilIdle()
        #expect(!exec.isRunning(argv: "/bin/sleep", ["0.2"]))
    }

    @Test("the list reads one name per line, blanks dropped, sorted")
    func parsesTheList() {
        #expect(
            AppleShortcuts.parse("Beta\n\nalpha\n  \nBeta\n")
                == ["alpha", "Beta"]
        )
    }

    @Test("a name the list does not carry is refused by name")
    func unknownIsRefused() {
        let core = makeTestCore()
        // `echo list` reads back one shortcut, `list`: no `Gone`.
        core.appleShortcuts.tool = "/bin/echo"
        core.appleShortcuts.setNamesForTesting(["Known"])
        let response = core.execute(
            "run_shortcut",
            args: [.string("Gone")]
        )
        #expect(response.error == "unknown shortcut: Gone")
    }

    @Test("no name is refused")
    func noNameIsRefused() {
        let core = makeTestCore()
        #expect(
            core.execute("run_shortcut").error
                == "expected a shortcut name"
        )
    }

    @Test("a known name runs, and the list is read again after")
    func knownRuns() async {
        let core = makeTestCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.appleShortcuts.tool = "/bin/echo"
        core.appleShortcuts.setNamesForTesting(["Known"])
        let response = core.execute(
            "run_shortcut",
            args: [.string("Known")]
        )
        #expect(response.isSuccess)
        #expect(log.contains("run_shortcut: running 'Known'"))
        await core.exec.untilIdle()
        // The run's exit re-read the list: `echo list` names one.
        #expect(core.appleShortcuts.names == ["list"])
    }

    @Test("a name the last list lacks is read again, then runs")
    func staleMissRuns() async {
        let core = makeTestCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.appleShortcuts.tool = "/bin/echo"
        core.appleShortcuts.setNamesForTesting(["Old"])
        let response = core.execute(
            "run_shortcut",
            args: [.string("list")]
        )
        #expect(response.isSuccess)
        #expect(log.contains("run_shortcut: running 'list'"))
        #expect(core.appleShortcuts.names == ["list"])
        await core.exec.untilIdle()
    }

    @Test("before any list read, a name it lacks is refused at once")
    func unreadListRefuses() async {
        let core = makeTestCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        core.appleShortcuts.tool = "/bin/echo"
        let response = core.execute(
            "run_shortcut",
            args: [.string("Gone")]
        )
        #expect(response.error == "unknown shortcut: Gone")
        #expect(log.contains("run_shortcut: no shortcut named 'Gone'"))
        #expect(!log.contains { $0.hasPrefix("run_shortcut: running") })
    }

    @Test("a list that cannot be read refuses nothing")
    func unreadableListRuns() async {
        let core = makeTestCore()
        var log: [String] = []
        core.onLog = { log.append($0) }
        let response = core.execute(
            "run_shortcut",
            args: [.string("Any")]
        )
        #expect(response.isSuccess)
        #expect(
            log.contains("run_shortcut: list unreadable, running 'Any'")
        )
        await core.exec.untilIdle()
    }

    @Test("an argv launch never shares a shell command's dedup key")
    func argvKeyIsApart() async {
        let exec = makeTestCore().exec
        exec.onLog = { _ in }
        let shell = exec.launch("/bin/sleep 0.2", dedup: true)
        let argv = exec.launch(argv: "/bin/sleep", ["0.2"], dedup: true)
        // One text, two argument splits: a space join made them one.
        let pair = exec.launch(argv: "/bin/sleep", ["0.2", "0"], dedup: true)
        let joined = exec.launch(argv: "/bin/sleep", ["0.2 0"], dedup: true)
        #expect(shell != nil)
        #expect(argv != nil)
        #expect(pair != nil)
        #expect(joined != nil)
        await exec.untilIdle()
    }

    @Test("a failed list read answers its waiters with nil")
    func failedReadAnswers() async {
        let core = makeTestCore()
        var answer: [String]?? = .none
        core.appleShortcuts.refresh { answer = .some($0) }
        await core.exec.untilIdle()
        #expect(answer == .some(nil))
        #expect(core.appleShortcuts.names == nil)
    }

    @Test("a list read that cannot start answers its waiters at once")
    func unstartableReadAnswers() {
        let core = makeTestCore()
        core.exec.onLog = { _ in }
        core.appleShortcuts.tool = "/nonexistent/shortcuts"
        var answer: [String]?? = .none
        core.appleShortcuts.refresh { answer = .some($0) }
        #expect(answer == .some(nil))
    }

    @Test("run_shortcut routes through mcp's run_destructive")
    func isDestructive() {
        #expect(APIReference.destructive.contains("run_shortcut"))
    }
}
