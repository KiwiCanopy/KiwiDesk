import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests for `LuaInterpreter.makeFunction(body:)` (#55 phase 3).
/// Ref lifecycle: mint in VM → register in `keys` → released by
/// `keys.reset()` (which calls `lua.release(ref:)` for every
/// stored ref). VM-safety: refs are only delivered to the
/// interpreter that minted them (AGENTS.md §5 lua guardrail).
@Suite("LuaInterpreter.makeFunction(body:)", .serialized)
@MainActor
struct LuaMakeFunctionTests {

    // MARK: - Successful compilation

    @Test("Valid body returns a callable ref")
    func validBodyReturnsRef() throws {
        let lua = try #require(LuaInterpreter())
        let result = lua.makeFunction(body: "x = 42")
        guard case .success(let ref) = result else {
            Issue.record("expected .success")
            return
        }
        // The ref must be a valid callable.
        #expect(lua.call(ref: ref).succeeded)
        // The body ran: x is now 42.
        #expect(lua.global("x") == .number(42))
        lua.release(ref: ref)
    }

    @Test("Valid multi-line body compiles and runs correctly")
    func multilineBody() throws {
        let lua = try #require(LuaInterpreter())
        let body = """
            result = 0
            for i = 1, 5 do
                result = result + i
            end
            """
        let result = lua.makeFunction(body: body)
        guard case .success(let ref) = result else {
            Issue.record("expected .success")
            return
        }
        #expect(lua.call(ref: ref).succeeded)
        #expect(lua.global("result") == .number(15))
        lua.release(ref: ref)
    }

    // MARK: - Compile errors

    @Test("Syntax error returns .failure, mints no ref")
    func syntaxErrorReturnsFailure() throws {
        let lua = try #require(LuaInterpreter())
        let result = lua.makeFunction(body: "this is not lua !!")
        guard case .failure(let err) = result else {
            Issue.record("expected .failure")
            return
        }
        if case .runtime(let message) = err {
            #expect(!message.isEmpty)
        } else {
            Issue.record("expected .runtime error")
        }
        // VM is still usable.
        #expect(lua.run("y = 7").succeeded)
    }

    @Test("Empty body compiles to a no-op function")
    func emptyBodyCompiles() throws {
        let lua = try #require(LuaInterpreter())
        let result = lua.makeFunction(body: "")
        guard case .success(let ref) = result else {
            Issue.record("expected .success")
            return
        }
        #expect(lua.call(ref: ref).succeeded)
        lua.release(ref: ref)
    }

    // MARK: - Wrapper escape (watchdog)

    /// A crafted body can escape the `return function()…end`
    /// wrapper and execute code during the compile pcall. That
    /// pcall runs under the watchdog deadline, so an escaped
    /// infinite loop must come back as a bounded failure —
    /// never a main-thread freeze.
    @Test("Wrapper-escaping body is watchdog-bounded")
    func escapedBodyIsBounded() throws {
        let lua = try #require(LuaInterpreter())
        lua.timeout = 0.05
        let body =
            "end, (function() while true do end end)(), "
            + "function()"
        let result = lua.makeFunction(body: body)
        guard case .failure = result else {
            Issue.record("escape must be stopped, not succeed")
            return
        }
        // VM survives the timeout.
        #expect(lua.run("ok = 1").succeeded)
    }

    // MARK: - Ref lifecycle (VM-safety, AGENTS.md §5)

    @Test("Ref from makeFunction is released without leak")
    func refReleasedCleanly() throws {
        let lua = try #require(LuaInterpreter())
        let result = lua.makeFunction(body: "-- noop")
        guard case .success(let ref) = result else {
            Issue.record("expected .success")
            return
        }
        // Release the ref — must not crash or leave the VM
        // in a bad state.
        lua.release(ref: ref)
        // VM is still usable after release.
        #expect(lua.run("z = 3").succeeded)
    }

    @Test("keys.reset() releases makeFunction refs via lua")
    func keysResetReleasesRefs() throws {
        let lua = try #require(LuaInterpreter())
        let keys = KeybindingManager(
            registrar: MockHotkeyRegistrar()
        )
        keys.lua = lua

        guard
            let combo = KeyCombo.parse("alt+h"),
            case .success(let ref) = lua.makeFunction(
                body: "z = 1"
            )
        else {
            Issue.record("setup failed")
            return
        }
        keys.bind(combo, ref: ref)
        #expect(keys.bindings(for: "default")[combo] != nil)

        // reset() must release the ref via lua (VM-safe).
        keys.reset()
        #expect(keys.bindings(for: "default").isEmpty)
        // VM survives the release.
        #expect(lua.run("w = 9").succeeded)
    }
}

// MARK: - Helpers

extension Result {
    fileprivate var succeeded: Bool {
        if case .success = self { return true }
        return false
    }
}

/// Stub registrar that accepts registrations without touching
/// the real Carbon event system.
@MainActor
private final class MockHotkeyRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}
