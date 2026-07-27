import Foundation
import Testing

@testable import KiwiDeskCore

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}

@MainActor
private func makeCore() -> KiwiCore {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(
            "kiwidesk-exec-tests-\(UUID().uuidString)"
        )
    let core = makeTestCore(configDirectory: directory)
    core.loadConfig()
    return core
}

/// Generous hang-guard for the async waits below (#344). These
/// tests spawn real subprocesses and await their callbacks on the
/// main actor; because swift-testing runs suites concurrently, the
/// shared main actor can be starved for seconds under full-suite
/// load, so a tight deadline tripped spuriously (the reported
/// `code → .none` flake). The happy path exits the instant the
/// condition holds, so a large value never slows a passing run — it
/// only bounds a genuine hang. What proves the *behavior* is the gap
/// between a watchdog and its sleep, not this deadline (see
/// `execTimeout` / `timeoutChildExitsFirst`).
private let execHangGuard: TimeInterval = 30

/// Polls the Lua global until it is non-nil or the timeout
/// elapses (exec callbacks arrive via the main-actor queue).
@MainActor
private func awaitGlobal(
    _ lua: LuaInterpreter,
    _ name: String,
    timeout: TimeInterval = execHangGuard
) async throws -> LuaValue {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let value = lua.global(name)
        if value != .none { return value }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    return .none
}

/// Waits for the launcher to reap every child (running count back to
/// zero) or the hang-guard elapses. Centralizes the reap-wait the
/// async tests repeat, on the same generous deadline (#344).
@MainActor
private func awaitReaped(
    _ core: KiwiCore,
    timeout: TimeInterval = execHangGuard
) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while core.exec.runningCount > 0, Date() < deadline {
        try await Task.sleep(nanoseconds: 20_000_000)
    }
}

@Suite("External command execution", .serialized)
@MainActor
struct ExecTests {
    @Test("os.execute returns immediately, never blocking")
    func osExecuteIsNonBlocking() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        let started = Date()
        let result = lua.run("ok = os.execute('sleep 2')")
        let elapsed = Date().timeIntervalSince(started)
        #expect(result.succeeded)
        // system() would sit in a kernel wait for 2s; the
        // async replacement returns right away.
        #expect(elapsed < 1.0)
        #expect(lua.global("ok") == .bool(true))
    }

    @Test("os.execute() without a command reports a shell")
    func osExecuteShellQuery() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        #expect(
            lua.run("has_shell = os.execute()").succeeded
        )
        #expect(lua.global("has_shell") == .bool(true))
    }

    @Test("exec delivers exit code, stdout, and stderr")
    func execCallback() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        let result = lua.run(
            """
            KiwiDesk.exec(
                "printf hello; printf oops 1>&2; exit 3",
                function(code, out, err)
                    got_code = code
                    got_out = out
                    got_err = err
                end)
            """
        )
        #expect(result.succeeded)
        let code = try await awaitGlobal(lua, "got_code")
        #expect(code == .number(3))
        #expect(lua.global("got_out") == .string("hello"))
        #expect(lua.global("got_err") == .string("oops"))
    }

    @Test("exec without callback returns a pid and reaps")
    func execFireAndForget() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        #expect(
            lua.run("pid = KiwiDesk.exec('true')").succeeded
        )
        guard
            case .number(let pid) = lua.global("pid")
        else {
            Issue.record("expected a pid")
            return
        }
        #expect(pid > 0)
        // The launcher lets go of the Process once reaped.
        try await awaitReaped(core)
        #expect(core.exec.runningCount == 0)
    }

    @Test("config reload drops pending exec callbacks")
    func reloadDropsPendingCallbacks() async throws {
        let core = makeCore()
        let lua1 = try #require(core.lua)
        #expect(
            lua1.run(
                """
                KiwiDesk.exec("sleep 0.2", function()
                    hit = true
                end)
                """
            ).succeeded
        )
        // Reload swaps in a fresh VM; the pending ref was
        // minted in the old one and must never cross over.
        core.loadConfig()
        let lua2 = try #require(core.lua)
        try await awaitReaped(core)
        // Child was reaped, but the callback went nowhere:
        // neither VM saw it.
        #expect(core.exec.runningCount == 0)
        #expect(lua2.global("hit") == .none)
        // The fresh VM is fully functional afterwards.
        #expect(lua2.run("sane = 1").succeeded)
        #expect(lua2.global("sane") == .number(1))
    }

    @Test("io.popen is disabled with a pointer to exec")
    func popenDisabled() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        #expect(
            lua.run(
                "h, msg = io.popen('ls')"
            ).succeeded
        )
        #expect(lua.global("h") == .none)
        guard
            case .string(let message) = lua.global("msg")
        else {
            Issue.record("expected an error message")
            return
        }
        #expect(message.contains("KiwiDesk.exec"))
    }

    @Test("os.exit is neutralized — does not kill the app")
    func osExitNeutralized() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // If os.exit were real, this would kill the test
        // process. Reaching the next line proves it is safe.
        #expect(lua.run("os.exit(0)").succeeded)
        #expect(lua.run("still_alive = true").succeeded)
        #expect(
            lua.global("still_alive") == .bool(true)
        )
    }

    @Test("Large output is truncated at 1 MB with a marker")
    func outputCapTruncation() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // 'yes x' writes "x\n" until head closes the pipe
        // at 2 MB; the cap stops capture at 1 MB.
        let script = """
            KiwiDesk.exec(
                "yes x | head -c 2097152",
                function(code, out, err)
                    cap_out = out
                end)
            """
        #expect(lua.run(script).succeeded)
        let out = try await awaitGlobal(lua, "cap_out")
        guard case .string(let text) = out else {
            Issue.record("expected string output")
            return
        }
        #expect(text.contains("[output truncated at 1 MB]"))
        // 1 MB content + short marker — not more.
        #expect(text.utf8.count <= 1_048_576 + 64)
    }

    @Test("Timed-out child is terminated and reaped")
    func execTimeout() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // Third arg is timeout in seconds.
        let script = """
            KiwiDesk.exec("sleep 30",
                function(code, out, err)
                    timeout_code = code
                end, 0.4)
            """
        #expect(lua.run(script).succeeded)
        let code = try await awaitGlobal(lua, "timeout_code")
        // Prove the 0.4s watchdog terminated the child via its exit
        // code, not wall-clock: a SIGTERM-killed `sleep 30` exits
        // non-zero, whereas a completed one exits 0. This can't be
        // tripped by main-actor starvation delaying the callback (a
        // tight `elapsed <` bound could).
        #expect(code != .none)
        #expect(code != .number(0))
        // Process was reaped after termination.
        try await awaitReaped(core)
        #expect(core.exec.runningCount == 0)
    }

    @Test("Timeout with an early-exiting child reaps once")
    func timeoutChildExitsFirst() async throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // The child exits immediately; the long 30s watchdog must
        // not fire (the normal reap cancels it) and the callback must
        // run exactly once with the real code. The watchdog is wide so
        // a load-starved exit callback still lands well before it.
        let script = """
            _calls = 0
            KiwiDesk.exec("true",
                function(code, out, err)
                    _calls = _calls + 1
                    _code = code
                end, 30)
            """
        #expect(lua.run(script).succeeded)
        let code = try await awaitGlobal(lua, "_code")
        #expect(code == .number(0))
        // Reaped promptly; the pending watchdog was cancelled.
        try await awaitReaped(core)
        #expect(core.exec.runningCount == 0)
        #expect(lua.global("_calls") == .number(1))
    }

    @Test("get_state includes exec_running count")
    func getStateExecRunning() async throws {
        let core = makeCore()
        // Before any launch: exec_running must be 0.
        let before = core.execute("get_state")
        guard case .object(let b)? = before.data else {
            Issue.record("expected state object")
            return
        }
        #expect(b["exec_running"] == .number(0))
        // While a child runs, count is 1.
        core.exec.launch("sleep 5")
        let during = core.execute("get_state")
        guard case .object(let d)? = during.data else {
            Issue.record("expected state object")
            return
        }
        #expect(d["exec_running"] == .number(1))
    }

    @Test("Lua-only functions appear in help() output")
    func luaOnlyInHelp() throws {
        let core = makeCore()
        let response = core.execute("help")
        guard case .array(let names)? = response.data else {
            Issue.record("expected command list")
            return
        }
        for name in APIReference.luaOnly {
            #expect(names.contains(.string(name)))
        }
    }

    @Test("Every luaOnly name is a real KiwiDesk function")
    func luaOnlyNamesAreRegistered() throws {
        let core = makeCore()
        let lua = try #require(core.lua)
        // Drives off APIReference.luaOnly so the list can't
        // name a function that was never registered (or drift
        // out of sync with the real Lua surface) — the parity
        // guard the reflection net can't provide here.
        let checks = APIReference.luaOnly
            .map { "type(KiwiDesk.\($0)) == 'function'" }
            .joined(separator: "\n    and ")
        #expect(lua.run("_ok = (\(checks))").succeeded)
        #expect(lua.global("_ok") == .bool(true))
    }

    @Test("did-you-mean never suggests a Lua-only command")
    func suggestionExcludesLuaOnly() {
        // The unknown-command path is reached over the socket
        // too, where a Lua-only name is a dead-end hint (#37).
        for name in APIReference.luaOnly {
            #expect(APIReference.suggestion(for: name + "x") != name)
        }
    }
}
