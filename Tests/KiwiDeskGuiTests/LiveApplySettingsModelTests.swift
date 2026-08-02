import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class SettingsLiveRegistrar: HotkeyRegistrar {
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

@Suite("Settings recorder-only live apply", .serialized)
@MainActor
struct LiveApplySettingsModelTests {
    private func makeModel() throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore(
            hotkeyRegistrar: SettingsLiveRegistrar()
        )
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "marker = 'clean'"
                    )
                ]
            )
        ]
        try core.saveGuiConfig(config)
        return (SettingsModel(core: core), core)
    }

    private func defaultBinding(
        in model: SettingsModel
    ) throws -> (layer: Int, binding: Int) {
        let layer = try #require(
            model.config.layers.firstIndex {
                $0.name == KeyLayer.defaultName
            }
        )
        let binding = try #require(
            model.config.layers[layer].bindings.firstIndex {
                $0.combo == "alt+h"
            }
        )
        return (layer, binding)
    }

    private func isRegistered(
        _ combo: String,
        core: KiwiCore
    ) throws -> Bool {
        let parsed = try #require(KeyCombo.parse(combo))
        return core.keys.bindings(for: "default")[parsed] != nil
    }

    @Test("Staged Lua edit does not hitchhike on recording")
    func stagedActionStaysStaged() throws {
        let (model, core) = try makeModel()
        let index = try defaultBinding(in: model)
        let id = model.config.layers[index.layer]
            .bindings[index.binding].id
        model.config.layers[index.layer]
            .bindings[index.binding].lua = "marker = 'staged'"
        model.config.layers[index.layer]
            .bindings[index.binding].combo = "alt+j"

        let feedback = model.liveApplyRecorded(
            layerName: "default",
            bindingID: id,
            combo: "alt+j"
        )
        #expect(feedback?.status == .applied)

        let combo = try #require(KeyCombo.parse("alt+j"))
        let ref = try #require(
            core.keys.bindings(for: "default")[combo]
        )
        let lua = try #require(core.lua)
        _ = lua.call(ref: ref)
        #expect(lua.global("marker") == .string("clean"))
        #expect(
            model.config.layers[index.layer]
                .bindings[index.binding].lua
                == "marker = 'staged'"
        )
    }

    @Test("Corrupt sidecar falls back to in-memory snapshot")
    func corruptSidecarRollback() throws {
        let (model, core) = try makeModel()
        let index = try defaultBinding(in: model)
        let id = model.config.layers[index.layer]
            .bindings[index.binding].id
        model.config.layers[index.layer]
            .bindings[index.binding].combo = "alt+j"
        _ = model.liveApplyRecorded(
            layerName: "default",
            bindingID: id,
            combo: "alt+j"
        )
        #expect(try isRegistered("alt+j", core: core))

        try Data("{broken".utf8).write(
            to: core.configDirectory
                .appendingPathComponent("gui.json")
        )
        model.revert()

        #expect(!(try isRegistered("alt+j", core: core)))
        #expect(try isRegistered("alt+h", core: core))
        #expect(model.liveKeySession == nil)
        #expect(model.profileWarning != nil)
    }

    @Test("Failed rollback keeps session for retry")
    func rollbackRetry() throws {
        let (model, core) = try makeModel()
        let index = try defaultBinding(in: model)
        let id = model.config.layers[index.layer]
            .bindings[index.binding].id
        model.config.layers[index.layer]
            .bindings[index.binding].combo = "alt+j"
        _ = model.liveApplyRecorded(
            layerName: "default",
            bindingID: id,
            combo: "alt+j"
        )
        let lua = try #require(core.keys.lua)
        core.keys.lua = nil

        model.revert()
        #expect(model.liveKeySession != nil)
        #expect(model.profileWarning != nil)

        core.keys.lua = lua
        model.revert()
        #expect(model.liveKeySession == nil)
        #expect(!(try isRegistered("alt+j", core: core)))
        #expect(try isRegistered("alt+h", core: core))
    }

    @Test("Raw Lua save supersedes recorder snapshot")
    func rawLuaSaveWins() throws {
        let (model, core) = try makeModel()
        let index = try defaultBinding(in: model)
        let id = model.config.layers[index.layer]
            .bindings[index.binding].id
        _ = model.liveApplyRecorded(
            layerName: "default",
            bindingID: id,
            combo: "alt+j"
        )
        #expect(try isRegistered("alt+j", core: core))

        model.luaSource = """
            KiwiDesk.bind("alt+k", function()
                marker = "raw"
            end)
            """
        model.saveLuaSource()

        #expect(model.liveKeySession == nil)
        #expect(!(try isRegistered("alt+j", core: core)))
        #expect(try isRegistered("alt+k", core: core))
    }

    @Test("Alias steal removes the clean runtime holder")
    func aliasSteal() throws {
        let (model, core) = try makeModel()
        model.config.layers[0].bindings[0].combo = ""
        let target = KeyBinding(
            combo: "option+h",
            lua: "marker = 'target'"
        )
        model.config.layers[0].bindings.append(target)

        let feedback = model.liveApplyRecorded(
            layerName: "default",
            bindingID: target.id,
            combo: target.combo
        )

        #expect(feedback?.status == .applied)
        let combo = try #require(KeyCombo.parse("alt+h"))
        let ref = try #require(
            core.keys.bindings(for: "default")[combo]
        )
        let lua = try #require(core.lua)
        _ = lua.call(ref: ref)
        #expect(lua.global("marker") == .string("target"))
    }

    @Test("Newer raw reload retires the recorder snapshot")
    func rawReloadSupersedesSnapshot() throws {
        let (model, core) = try makeModel()
        let index = try defaultBinding(in: model)
        let id = model.config.layers[index.layer]
            .bindings[index.binding].id
        _ = model.liveApplyRecorded(
            layerName: "default",
            bindingID: id,
            combo: "alt+j"
        )
        #expect(try isRegistered("alt+j", core: core))

        try """
        KiwiDesk.bind("alt+k", function()
            marker = "raw"
        end)
        """.write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        core.loadConfig()
        model.revert()

        #expect(model.liveKeySession == nil)
        #expect(!(try isRegistered("alt+h", core: core)))
        #expect(!(try isRegistered("alt+j", core: core)))
        #expect(try isRegistered("alt+k", core: core))
    }
}
