import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private final class TrackingLiveRegistrar: HotkeyRegistrar {
    var deniedKeyCodes: Set<UInt32> = []
    private(set) var registrationCalls = 0
    private(set) var unregistrationCalls = 0
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        registrationCalls += 1
        guard !deniedKeyCodes.contains(keyCode) else {
            return nil
        }
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {
        unregistrationCalls += 1
    }

    func resetCounts() {
        registrationCalls = 0
        unregistrationCalls = 0
    }
}

@Suite("Live-apply status and batching (#123)", .serialized)
@MainActor
struct LiveApplyKeybindingStatusTests {
    private func makeCore(
        registrar: TrackingLiveRegistrar
    ) -> KiwiCore {
        KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-live-status-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: registrar
        )
    }

    private func binding(
        _ combo: String,
        lua: String
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua)
    }

    private func configWithTwoDefaults() -> GuiConfig {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    binding("alt+h", lua: "left = true"),
                    binding("alt+l", lua: "right = true"),
                ]
            )
        ]
        return config
    }

    @Test("Inactive-mode recording never claims Active now")
    func inactiveModeStatus() throws {
        let registrar = TrackingLiveRegistrar()
        let core = makeCore(registrar: registrar)
        var config = configWithTwoDefaults()
        config.modes.append(
            KeyMode(
                name: "resize",
                bindings: [binding("h", lua: "small = true")]
            )
        )
        try core.saveGuiConfig(config)

        var edited = config.modes
        edited[1].bindings[0].combo = "j"
        let target = edited[1].bindings[0]
        let result = core.liveApplyKeybindings(
            modes: edited,
            target: .init(mode: "resize", binding: target)
        )

        guard case .success(.inactiveMode("resize")) = result
        else {
            Issue.record("expected inactive resize status")
            return
        }
        let combo = try #require(KeyCombo.parse("j"))
        #expect(core.keys.bindings(for: "resize")[combo] != nil)
    }

    @Test("Target compile failure preserves the old table")
    func compileFailureIsTransactional() throws {
        let registrar = TrackingLiveRegistrar()
        let core = makeCore(registrar: registrar)
        let config = configWithTwoDefaults()
        try core.saveGuiConfig(config)

        var edited = config.modes
        let invalid = binding(
            "alt+j",
            lua: "this is not valid Lua !!"
        )
        edited[0].bindings.append(invalid)
        let result = core.liveApplyKeybindings(
            modes: edited,
            target: .init(mode: "default", binding: invalid)
        )

        guard case .success(.compileFailed) = result else {
            Issue.record("expected compile-failed status")
            return
        }
        let old = try #require(KeyCombo.parse("alt+h"))
        let added = try #require(KeyCombo.parse("alt+j"))
        #expect(core.keys.bindings(for: "default")[old] != nil)
        #expect(core.keys.bindings(for: "default")[added] == nil)
    }

    @Test("Carbon denial is scoped to the active target")
    func deniedStatus() throws {
        let registrar = TrackingLiveRegistrar()
        let core = makeCore(registrar: registrar)
        let config = configWithTwoDefaults()
        try core.saveGuiConfig(config)

        var edited = config.modes
        let denied = binding("alt+j", lua: "hit = true")
        edited[0].bindings.append(denied)
        let parsed = try #require(KeyCombo.parse("alt+j"))
        registrar.deniedKeyCodes = [parsed.keyCode]
        let result = core.liveApplyKeybindings(
            modes: edited,
            target: .init(mode: "default", binding: denied)
        )

        guard case .success(.denied) = result else {
            Issue.record("expected denied status")
            return
        }
        #expect(core.keys.activationFailures.contains(parsed))
    }

    @Test("One live swap registers the active mode once")
    func batchRegistrationIsLinear() throws {
        let registrar = TrackingLiveRegistrar()
        let core = makeCore(registrar: registrar)
        let config = configWithTwoDefaults()
        try core.saveGuiConfig(config)
        registrar.resetCounts()
        var modeEvents: [String] = []
        core.keys.onModeChange = { modeEvents.append($0) }

        var edited = config.modes
        let added = binding("alt+j", lua: "middle = true")
        edited[0].bindings.append(added)
        _ = core.liveApplyKeybindings(
            modes: edited,
            target: .init(mode: "default", binding: added)
        )

        #expect(registrar.registrationCalls == 3)
        #expect(registrar.unregistrationCalls == 2)
        #expect(modeEvents.isEmpty)
    }
}
