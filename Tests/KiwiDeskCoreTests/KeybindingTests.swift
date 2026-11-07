import Foundation
import Testing

@testable import KiwiDeskCore

/// Fake registrar capturing registrations.
@MainActor
private final class FakeRegistrar: HotkeyRegistrar {
    var handlers: [UInt32: @MainActor () -> Void] = [:]
    var registered: [UInt32: (UInt32, HotkeyModifiers)] = [:]
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        let id = nextID
        nextID += 1
        handlers[id] = handler
        registered[id] = (keyCode, modifiers)
        return id
    }

    func unregister(id: UInt32) {
        handlers[id] = nil
        registered[id] = nil
    }

    func press(keyCode: UInt32) {
        for (id, entry) in registered
        where entry.0 == keyCode {
            handlers[id]?()
        }
    }
}

@Suite("KeybindingManager", .serialized)
@MainActor
struct KeybindingManagerTests {
    @Test("Modal switching swaps the active bindings")
    func modalSwitching() throws {
        let registrar = FakeRegistrar()
        let manager = KeybindingManager(
            registrar: registrar
        )
        let lua = try #require(LuaInterpreter())
        manager.lua = lua

        var captured: [Int32] = []
        lua.register("grab") { args in
            if case .functionRef(let ref) = args.first {
                captured.append(ref)
            }
            return .none
        }
        lua.run(
            """
            KiwiDesk.grab(function() hits = (hits or 0) + 1 end)
            KiwiDesk.grab(function() resized = true end)
            """
        )
        expectEqual(captured.count, 2)

        let bindCombo = try #require(
            KeyCombo.parse("cmd+alt+h")
        )
        let modeCombo = try #require(KeyCombo.parse("h"))
        manager.bind(bindCombo, ref: captured[0])
        manager.defineLayer(
            "resize",
            bindings: [modeCombo: captured[1]]
        )

        // Default layer: only the global bind is active.
        expectEqual(registrar.registered.count, 1)
        registrar.press(keyCode: bindCombo.keyCode)
        expectEqual(lua.global("hits"), .number(1))

        // Resize layer: only the layer bindings are active.
        manager.switchLayer("resize")
        expectEqual(manager.currentLayer, "resize")
        expectEqual(registrar.registered.count, 1)
        registrar.press(keyCode: modeCombo.keyCode)
        expectEqual(lua.global("resized"), .bool(true))

        // Back to default.
        manager.switchLayer("default")
        registrar.press(keyCode: bindCombo.keyCode)
        expectEqual(lua.global("hits"), .number(2))
    }

    @Test("Failing callbacks are disabled, not retried")
    func faultyCallbackDisabled() throws {
        let registrar = FakeRegistrar()
        let manager = KeybindingManager(
            registrar: registrar
        )
        let lua = try #require(LuaInterpreter())
        manager.lua = lua
        var logs: [String] = []
        manager.onLog = { logs.append($0) }

        var ref: Int32?
        lua.register("grab") { args in
            if case .functionRef(let r) = args.first {
                ref = r
            }
            return .none
        }
        lua.run("KiwiDesk.grab(function() error('kaput') end)")
        let combo = try #require(KeyCombo.parse("cmd+k"))
        manager.bind(combo, ref: try #require(ref))

        registrar.press(keyCode: combo.keyCode)
        #expect(logs.contains { $0.contains("disabled") })
        // The binding is gone after the failure.
        #expect(registrar.registered.isEmpty)
    }

    @Test("Suspend unregisters hotkeys; resume restores them")
    func suspendResume() throws {
        let registrar = FakeRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let lua = try #require(LuaInterpreter())
        manager.lua = lua

        var ref: Int32?
        lua.register("grab") { args in
            if case .functionRef(let r) = args.first { ref = r }
            return .none
        }
        lua.run(
            "KiwiDesk.grab(function() fired = (fired or 0) + 1 end)"
        )
        let combo = try #require(KeyCombo.parse("cmd+alt+h"))
        manager.bind(combo, ref: try #require(ref))
        expectEqual(registrar.registered.count, 1)

        // Armed recorder: nothing registered.
        manager.suspend()
        #expect(manager.isSuspended)
        #expect(registrar.registered.isEmpty)
        // Idempotent.
        manager.suspend()
        #expect(registrar.registered.isEmpty)

        // Disarm: the same combo is live again and fires.
        manager.resume()
        #expect(!manager.isSuspended)
        expectEqual(registrar.registered.count, 1)
        registrar.press(keyCode: combo.keyCode)
        expectEqual(lua.global("fired"), .number(1))
        // Idempotent resume does not double-register.
        manager.resume()
        expectEqual(registrar.registered.count, 1)
    }

    @Test("A layer change during suspension registers on resume")
    func suspendHonorsModeChange() throws {
        let registrar = FakeRegistrar()
        let manager = KeybindingManager(registrar: registrar)
        let lua = try #require(LuaInterpreter())
        manager.lua = lua

        var captured: [Int32] = []
        lua.register("grab") { args in
            if case .functionRef(let r) = args.first {
                captured.append(r)
            }
            return .none
        }
        lua.run(
            """
            KiwiDesk.grab(function() base = true end)
            KiwiDesk.grab(function() resized = true end)
            """
        )
        let bindCombo = try #require(KeyCombo.parse("cmd+alt+h"))
        let modeCombo = try #require(KeyCombo.parse("j"))
        manager.bind(bindCombo, ref: captured[0])
        manager.defineLayer(
            "resize",
            bindings: [modeCombo: captured[1]]
        )

        manager.suspend()
        manager.switchLayer("resize")
        // Still suspended: the switch registered nothing.
        #expect(registrar.registered.isEmpty)

        manager.resume()
        // Resume registers the layer current *now*, not default.
        expectEqual(registrar.registered.count, 1)
        registrar.press(keyCode: modeCombo.keyCode)
        expectEqual(lua.global("resized"), .bool(true))
        expectEqual(lua.global("base"), LuaValue.none)
    }

    @Test("Unknown layers are rejected")
    func unknownMode() {
        let manager = KeybindingManager(
            registrar: FakeRegistrar()
        )
        var logs: [String] = []
        manager.onLog = { logs.append($0) }
        manager.switchLayer("nope")
        expectEqual(manager.currentLayer, "default")
        #expect(logs.contains { $0.contains("nope") })
    }
}
