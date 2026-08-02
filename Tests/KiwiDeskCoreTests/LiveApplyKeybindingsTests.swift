import Foundation
import Testing

@testable import KiwiDeskCore

@MainActor
private final class AcceptingLiveRegistrar: HotkeyRegistrar {
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

/// Recorder-only live apply: effective registrations change,
/// persistence does not; saved state and snapshots both restore.
@Suite("Live-apply keybindings (#123)", .serialized)
@MainActor
struct LiveApplyKeybindingsTests {
    private func makeGuiCore() -> KiwiCore {
        makeTestCore(
            hotkeyRegistrar: AcceptingLiveRegistrar()
        )
    }

    private func binding(
        _ combo: String,
        lua: String
    ) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua)
    }

    private func baseConfig() -> GuiConfig {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: "default",
                bindings: [
                    binding("alt+h", lua: "marker = 'base'")
                ]
            )
        ]
        return config
    }

    private func registered(
        _ combo: String,
        layer: String = "default",
        core: KiwiCore
    ) throws -> Bool {
        let parsed = try #require(KeyCombo.parse(combo))
        return core.keys.bindings(for: layer)[parsed] != nil
    }

    private func fire(
        _ combo: String,
        readGlobal name: String,
        core: KiwiCore
    ) throws -> LuaValue {
        let parsed = try #require(KeyCombo.parse(combo))
        let ref = try #require(
            core.keys.bindings(for: "default")[parsed]
        )
        let lua = try #require(core.lua)
        _ = lua.call(ref: ref)
        return lua.global(name)
    }

    @Test("Edited layers register live; gui.json stays untouched")
    func editedModesRegisterWithoutPersisting() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())

        var edited = baseConfig().layers
        let added = binding("alt+j", lua: "hit = true")
        edited[0].bindings.append(added)
        let result = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: added)
        )

        guard case .success(.active) = result else {
            Issue.record("expected active live apply")
            return
        }
        #expect(
            try fire("alt+j", readGlobal: "hit", core: core)
                == .bool(true)
        )
        #expect(try registered("alt+h", core: core))
        let saved = try #require(core.guiConfigStore.load())
        #expect(saved.layers == baseConfig().layers)
    }

    @Test("A suspended recorder never live-applies as active")
    func suspendedNeverActive() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())

        var edited = baseConfig().layers
        let added = binding("alt+j", lua: "hit = true")
        edited[0].bindings.append(added)

        // Commit while still armed must not claim success: nothing
        // is registered, so `.active` would be a lie (#213).
        core.suspendHotkeysForRecording()
        let armed = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: added)
        )
        guard case .failure(.unavailable) = armed else {
            Issue.record("suspended apply must refuse, not lie")
            return
        }

        // Disarm, then the same apply registers and reports active.
        core.resumeHotkeysForRecording()
        let live = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: added)
        )
        guard case .success(.active) = live else {
            Issue.record("expected active after resume")
            return
        }
    }

    @Test("Saved state and the snapshot both restore")
    func restorePaths() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        let snapshot = try #require(
            core.liveKeybindingSnapshot()
        )

        var edited = baseConfig().layers
        let added = binding("alt+j", lua: "hit = true")
        edited[0].bindings.append(added)
        _ = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: added)
        )
        #expect(try registered("alt+j", core: core))

        #expect(core.restoreSavedLiveKeybindings().isSuccess)
        #expect(!(try registered("alt+j", core: core)))

        _ = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: added)
        )
        #expect(core.restoreLiveKeybindings(snapshot).isSuccess)
        #expect(!(try registered("alt+j", core: core)))
        #expect(try registered("alt+h", core: core))
    }

    @Test("Active profile shadowing is reported, not active")
    func profileOverrideShadowReported() throws {
        let core = makeGuiCore()
        try core.saveGuiConfig(baseConfig())
        let override = binding(
            "option+h",
            lua: "marker = 'override'"
        )
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings(),
                layers: KeyLayerOverride(
                    layers: [
                        KeyLayer(
                            name: "default",
                            bindings: [override]
                        )
                    ]
                )
            )
        )
        #expect(
            core.execute(
                "load_profile",
                args: [.string("Work")]
            ).isSuccess
        )

        var edited = baseConfig().layers
        edited[0].bindings[0].lua = "marker = 'edited'"
        let target = edited[0].bindings[0]
        let result = core.liveApplyKeybindings(
            layers: edited,
            target: .init(layer: "default", binding: target)
        )

        guard case .success(.profileShadowed) = result else {
            Issue.record("expected profile-shadowed status")
            return
        }
        #expect(
            try fire(
                "alt+h",
                readGlobal: "marker",
                core: core
            ) == .string("override")
        )
    }

    @Test("Surviving active layer is preserved")
    func activeModeSurvives() throws {
        let core = makeGuiCore()
        var config = baseConfig()
        config.layers.append(
            KeyLayer(
                name: "resize",
                bindings: [binding("h", lua: "shrunk = true")]
            )
        )
        try core.saveGuiConfig(config)
        core.keys.switchLayer("resize")

        _ = core.liveApplyKeybindings(
            layers: config.layers,
            target: .init(
                layer: "default",
                binding: config.layers[0].bindings[0]
            )
        )
        #expect(core.keys.currentLayer == "resize")
    }

    @Test("Removing the active layer falls back to default")
    func removedActiveModeFallsBack() throws {
        let core = makeGuiCore()
        var config = baseConfig()
        config.layers.append(KeyLayer(name: "resize"))
        try core.saveGuiConfig(config)
        core.keys.switchLayer("resize")

        _ = core.liveApplyKeybindings(
            layers: baseConfig().layers,
            target: .init(
                layer: "default",
                binding: baseConfig().layers[0].bindings[0]
            )
        )
        #expect(core.keys.currentLayer == "default")
    }
}

extension Result {
    fileprivate var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }
}
