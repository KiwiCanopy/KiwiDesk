import Foundation
import SwiftUI
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// What the Key sequences card writes reaches the files (#1871): a
/// sequence has no Lua, so the key table never names it, and it
/// rides the layer's rows whole.
@Suite("Key sequence card save (#1871)", .serialized)
@MainActor
struct KeySequenceCardSaveTests {
    private let left = "KiwiDesk.focus(\"left\")"

    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [KeyLayer(name: KeyLayer.defaultName)]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func sequence() -> KeyBinding {
        let branch = KeyBinding.sequence(
            combo: "w",
            label: "Windows",
            steps: [KeyBinding(combo: "h", lua: left, kind: .navigation)]
        )
        return .sequence(
            combo: "ctrl+alt+space",
            label: "Leader",
            steps: [branch]
        )
    }

    private func stored(_ model: SettingsModel) -> [KeyBinding] {
        model.core.guiConfigStore.load()?.layers.first?.sequences ?? []
    }

    @Test("the card blocks a stored page and a profile's own copy")
    func editBlocks() throws {
        let model = try makeModel()
        #expect(model.sequenceEditBlock(in: KeyLayer.defaultName) == nil)
        var work = try model.core.profiles.read(name: "Work")
        work.layers = KeyLayerOverride(
            layers: [
                KeyLayer(name: KeyLayer.defaultName, bindings: [sequence()])
            ]
        )
        try model.core.profiles.write(work)
        model.reload()
        #expect(
            model.sequenceEditBlock(in: KeyLayer.defaultName)
                == .profileOwnsSequences
        )
        model.selectEditTarget("Home")
        #expect(
            model.sequenceEditBlock(in: KeyLayer.defaultName) == .storedPage
        )
    }

    @Test("a sequence recorded on the live page lands whole")
    func liveSaveWritesTheTree() throws {
        let model = try makeModel()
        model.config.layers[0].bindings.append(sequence())
        #expect(model.isDirty)
        model.updateActiveProfile()

        #expect(stored(model) == [sequence()])
        #expect(!model.isDirty)
    }

    @Test("a step edited under a saved leader lands")
    func liveStepEditLands() throws {
        let model = try makeModel()
        model.config.layers[0].bindings.append(sequence())
        model.updateActiveProfile()
        let id = try #require(model.config.layers[0].sequences.first?.id)
        let editing = SequenceEditing(
            bindings: Binding(
                get: { model.config.layers[0].bindings },
                set: { model.config.layers[0].bindings = $0 }
            ),
            rootID: id
        )
        let branch = try #require(editing.root?.steps?.first)
        editing.update(branch.id) { $0.label = "Win" }
        #expect(model.isDirty)
        model.updateActiveProfile()

        #expect(stored(model).first?.steps?.first?.label == "Win")
    }
}
