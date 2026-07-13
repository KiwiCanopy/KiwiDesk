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
        #expect(captured.count == 2)

        let bindCombo = try #require(
            KeyCombo.parse("cmd+alt+h")
        )
        let modeCombo = try #require(KeyCombo.parse("h"))
        manager.bind(bindCombo, ref: captured[0])
        manager.defineMode(
            "resize",
            bindings: [modeCombo: captured[1]]
        )

        // Default mode: only the global bind is active.
        #expect(registrar.registered.count == 1)
        registrar.press(keyCode: bindCombo.keyCode)
        #expect(lua.global("hits") == .number(1))

        // Resize mode: only the mode bindings are active.
        manager.switchMode("resize")
        #expect(manager.currentMode == "resize")
        #expect(registrar.registered.count == 1)
        registrar.press(keyCode: modeCombo.keyCode)
        #expect(lua.global("resized") == .bool(true))

        // Back to default.
        manager.switchMode("default")
        registrar.press(keyCode: bindCombo.keyCode)
        #expect(lua.global("hits") == .number(2))
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
        #expect(registrar.registered.count == 1)

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
        #expect(registrar.registered.count == 1)
        registrar.press(keyCode: combo.keyCode)
        #expect(lua.global("fired") == .number(1))
        // Idempotent resume does not double-register.
        manager.resume()
        #expect(registrar.registered.count == 1)
    }

    @Test("A mode change during suspension registers on resume")
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
        manager.defineMode(
            "resize",
            bindings: [modeCombo: captured[1]]
        )

        manager.suspend()
        manager.switchMode("resize")
        // Still suspended: the switch registered nothing.
        #expect(registrar.registered.isEmpty)

        manager.resume()
        // Resume registers the mode current *now*, not default.
        #expect(registrar.registered.count == 1)
        registrar.press(keyCode: modeCombo.keyCode)
        #expect(lua.global("resized") == .bool(true))
        #expect(lua.global("base") == LuaValue.none)
    }

    @Test("Unknown modes are rejected")
    func unknownMode() {
        let manager = KeybindingManager(
            registrar: FakeRegistrar()
        )
        var logs: [String] = []
        manager.onLog = { logs.append($0) }
        manager.switchMode("nope")
        #expect(manager.currentMode == "default")
        #expect(logs.contains { $0.contains("nope") })
    }
}

@Suite("Crash recovery", .serialized)
@MainActor
struct CrashRecoveryTests {
    private func makeRecovery() -> (CrashRecovery, URL) {
        let directory = FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-crash-\(UUID().uuidString)"
            )
        return (CrashRecovery(directory: directory), directory)
    }

    private var sampleSnapshot: StateSnapshot {
        StateSnapshot(
            windows: [
                .init(
                    id: WindowID(1),
                    frame: CGRect(
                        x: 1,
                        y: 2,
                        width: 3,
                        height: 4
                    )
                )
            ],
            spaces: [],
            activeSpace: "1",
            capturedAt: Date(timeIntervalSince1970: 1000)
        )
    }

    @Test("Unclean shutdown restores the autosaved state")
    func uncleanRestore() {
        let (first, directory) = makeRecovery()
        first.captureState = { [sampleSnapshot] in
            sampleSnapshot
        }
        first.autosave()

        // Simulate a crash: new instance, same directory.
        let second = CrashRecovery(directory: directory)
        var restored: StateSnapshot?
        second.restoreState = { restored = $0 }
        second.start()
        #expect(restored == sampleSnapshot)
        second.shutdownCleanly()
    }

    @Test("Clean shutdown leaves nothing to restore")
    func cleanShutdown() {
        let (first, directory) = makeRecovery()
        first.captureState = { [sampleSnapshot] in
            sampleSnapshot
        }
        first.autosave()
        first.shutdownCleanly()

        let second = CrashRecovery(directory: directory)
        var restored: StateSnapshot?
        second.restoreState = { restored = $0 }
        second.start()
        #expect(restored == nil)
        second.shutdownCleanly()
    }
}
