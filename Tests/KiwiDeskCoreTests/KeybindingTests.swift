import Foundation
import Testing

@testable import KiwiDeskCore

@Suite("KeyCombo parsing")
struct KeyComboTests {
    @Test("comboString emits Mac words and round-trips")
    func comboStringRoundTrip() throws {
        let text = try #require(
            KeyCombo.comboString(
                keyCode: 15,
                command: false,
                option: true,
                control: true,
                shift: false
            )
        )
        #expect(text == "control+option+r")
        let parsed = try #require(KeyCombo.parse(text))
        #expect(parsed.modifiers == [.control, .option])
        #expect(parsed.keyCode == 15)
    }

    @Test("word aliases for punctuation keys parse")
    func punctuationAliases() throws {
        let combo = try #require(
            KeyCombo.parse("ctrl+alt+cmd+semicolon")
        )
        #expect(combo.keyCode == 41)
        #expect(
            combo.modifiers == [.control, .option, .command]
        )
        #expect(KeyCombo.parse("cmd+comma")?.keyCode == 43)
        #expect(KeyCombo.parse("alt+period")?.keyCode == 47)
        // The symbol form still works and matches the word.
        #expect(
            KeyCombo.parse("cmd+;")?.keyCode
                == KeyCombo.parse("cmd+semicolon")?.keyCode
        )
        // Display prefers the readable word form.
        #expect(
            KeyCombo.comboString(
                keyCode: 41,
                command: true,
                option: false,
                control: false,
                shift: false
            ) == "command+semicolon"
        )
    }

    @Test("comboString names disambiguate aliased codes")
    func comboStringNames() {
        #expect(
            KeyCombo.comboString(
                keyCode: 53,
                command: false,
                option: false,
                control: false,
                shift: false
            ) == "escape"
        )
        #expect(
            KeyCombo.comboString(
                keyCode: 36,
                command: true,
                option: false,
                control: false,
                shift: false
            ) == "command+return"
        )
    }

    @Test("Parses modifiers and key names")
    func parsing() throws {
        let combo = try #require(
            KeyCombo.parse("ctrl+alt+r")
        )
        #expect(combo.modifiers == [.control, .option])
        #expect(combo.keyCode == 15)

        let arrows = try #require(
            KeyCombo.parse("cmd+shift+left")
        )
        #expect(arrows.modifiers == [.command, .shift])
        #expect(arrows.keyCode == 123)
    }

    @Test("Single keys work for modal modes")
    func bareKey() throws {
        let combo = try #require(KeyCombo.parse("escape"))
        #expect(combo.modifiers == [])
        #expect(combo.keyCode == 53)
    }

    @Test("Rejects unknown keys and modifiers")
    func rejects() {
        #expect(KeyCombo.parse("hyper+x") == nil)
        #expect(KeyCombo.parse("cmd+notakey") == nil)
        #expect(KeyCombo.parse("") == nil)
    }
}

@Suite("KeybindingConflicts")
struct KeybindingConflictsTests {
    @Test("A duplicate combo within a mode is a conflict")
    func duplicateWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+h", lua: "b"),
        ]
        #expect(KeybindingConflicts.hasAny(bindings))
        #expect(
            KeybindingConflicts.text(
                for: bindings[0],
                in: bindings
            ) != nil
        )
    }

    @Test("Unique combos in one mode are not a conflict")
    func uniqueWithinMode() {
        let bindings = [
            KeyBinding(combo: "cmd+alt+h", lua: "a"),
            KeyBinding(combo: "cmd+alt+l", lua: "b"),
        ]
        #expect(!KeybindingConflicts.hasAny(bindings))
    }

    @Test(
        "The same combo in different modes is not a conflict"
    )
    func sameComboAcrossModes() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyMode(
                name: "resize",
                bindings: [KeyBinding(combo: "h", lua: "b")]
            ),
        ]
        #expect(
            !KeybindingConflicts.hasAnyAcrossModes(modes)
        )
    }

    @Test("A conflict inside any single mode is reported")
    func conflictWithinOneOfSeveralModes() {
        let modes = [
            KeyMode(
                name: "default",
                bindings: [KeyBinding(combo: "h", lua: "a")]
            ),
            KeyMode(
                name: "resize",
                bindings: [
                    KeyBinding(combo: "j", lua: "b"),
                    KeyBinding(combo: "j", lua: "c"),
                ]
            ),
        ]
        #expect(KeybindingConflicts.hasAnyAcrossModes(modes))
    }
}

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
