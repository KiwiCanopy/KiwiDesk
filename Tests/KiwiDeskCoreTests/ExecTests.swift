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
    let core = KiwiCore(configDirectory: directory)
    core.loadConfig()
    return core
}

/// Polls the Lua global until it is non-nil or the timeout
/// elapses (exec callbacks arrive via the main-actor queue).
@MainActor
private func awaitGlobal(
    _ lua: LuaInterpreter,
    _ name: String,
    timeout: TimeInterval = 5
) async throws -> LuaValue {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        let value = lua.global(name)
        if value != .none { return value }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    return .none
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
        let deadline = Date().addingTimeInterval(5)
        while core.exec.runningCount > 0, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
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
        let deadline = Date().addingTimeInterval(5)
        while core.exec.runningCount > 0, Date() < deadline {
            try await Task.sleep(nanoseconds: 20_000_000)
        }
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
}
