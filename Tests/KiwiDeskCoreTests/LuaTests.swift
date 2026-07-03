import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("LuaInterpreter", .serialized)
@MainActor
struct LuaTests {
    @Test("Runs plain Lua code and reads globals")
    func basicEval() throws {
        let lua = try #require(LuaInterpreter())
        let result = lua.run("answer = 21 * 2")
        #expect(result.succeeded)
        #expect(lua.global("answer") == .number(42))
    }

    @Test("Syntax errors are reported, not fatal")
    func syntaxError() throws {
        let lua = try #require(LuaInterpreter())
        guard
            case .failure(.runtime(let message)) =
                lua.run("this is not lua")
        else {
            Issue.record("expected a runtime failure")
            return
        }
        #expect(message.contains("syntax error"))
        // The VM stays usable afterwards.
        #expect(lua.run("x = 1").succeeded)
    }

    @Test("Infinite loops hit the 500ms sandbox timeout")
    func timeout() throws {
        let lua = try #require(LuaInterpreter())
        lua.timeout = 0.1
        let started = Date()
        let result = lua.run("while true do end")
        let elapsed = Date().timeIntervalSince(started)
        guard case .failure(.runtime(let message)) = result
        else {
            Issue.record("expected a timeout failure")
            return
        }
        #expect(message.contains("timed out"))
        #expect(elapsed < 2.0)
        // The VM survives the abort.
        #expect(lua.run("y = 5").succeeded)
    }

    @Test("Swift functions are callable from Lua")
    func registeredFunction() throws {
        let lua = try #require(LuaInterpreter())
        var received: [LuaValue] = []
        lua.register("set_gap") { args in
            received = args
            return .number(99)
        }
        let result = lua.run(
            "back = KiwiDesk.set_gap(12, 'space')"
        )
        #expect(result.succeeded)
        #expect(received == [.number(12), .string("space")])
        #expect(lua.global("back") == .number(99))
    }

    @Test("Lua callbacks are captured and callable")
    func functionCapture() throws {
        let lua = try #require(LuaInterpreter())
        var captured: Int32?
        lua.register("on") { args in
            if case .functionRef(let ref) = args.first {
                captured = ref
            }
            return .none
        }
        lua.run(
            """
            KiwiDesk.on(function(x)
                result = x * 10
            end)
            """
        )
        let ref = try #require(captured)
        #expect(
            lua.call(ref: ref, args: [.number(4)]).succeeded
        )
        #expect(lua.global("result") == .number(40))
        lua.release(ref: ref)
    }

    @Test("Table arguments bridge both directions")
    func tableBridging() throws {
        let lua = try #require(LuaInterpreter())
        var rules: LuaValue = .none
        lua.register("set_rules") { args in
            rules = args.first ?? .none
            return .table(["ok": .bool(true)])
        }
        lua.run(
            """
            reply = KiwiDesk.set_rules({
                "Calculator", "Finder:Get Info",
            })
            ok = reply.ok
            """
        )
        #expect(
            rules
                == .array([
                    .string("Calculator"),
                    .string("Finder:Get Info"),
                ])
        )
        #expect(lua.global("ok") == .bool(true))
    }

    @Test("Runtime errors carry the Lua message")
    func runtimeError() throws {
        let lua = try #require(LuaInterpreter())
        guard
            case .failure(.runtime(let message)) =
                lua.run("error('boom')")
        else {
            Issue.record("expected failure")
            return
        }
        #expect(message.contains("boom"))
    }
}

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}
