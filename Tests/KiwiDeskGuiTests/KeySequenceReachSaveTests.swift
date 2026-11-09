import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A key sequence's "Applies to" (#3124): the card edits a sequence
/// on a stored profile's page, a sequence reaches the profiles its
/// reach ticks, a tick a sequence clashes on is refused, and a
/// re-recorded leader keeps its reach.
@Suite("Key sequence reach save (#3124)", .serialized)
@MainActor
struct KeySequenceReachSaveTests {
    private let left = "KiwiDesk.focus(\"left\")"
    private let leader = "ctrl+alt+space"

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

    private func tree(_ combo: String? = nil, _ label: String = "Leader")
        -> KeyBinding
    {
        .sequence(
            combo: combo ?? leader,
            label: label,
            steps: [KeyBinding(combo: "h", lua: left, kind: .navigation)]
        )
    }

    private func key(_ combo: String? = nil) -> String {
        RuleReachTable<String>.sequenceID(
            layer: KeyLayer.defaultName,
            leader: combo ?? leader
        )
    }

    private func base(_ model: SettingsModel) -> [KeyBinding] {
        model.core.guiConfigStore.load()?.layers.first?.sequences ?? []
    }

    private func own(_ model: SettingsModel, _ name: String) throws
        -> [KeyBinding]
    {
        let base = model.core.guiConfigStore.load()?.layers ?? []
        let stored = try model.core.profiles.read(name: name).layers
        let layers = stored?.resolved(onto: base) ?? base
        return layers.first?.sequences ?? []
    }

    @Test("a sequence recorded on a stored page lands in that profile")
    func storedPageLands() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        model.config.layers[0].bindings.append(tree())
        #expect(model.isDirty)
        model.saveEditedProfile()

        #expect(try own(model, "Home") == [tree()])
        #expect(try own(model, "Work").isEmpty)
        #expect(base(model).isEmpty)
    }

    @Test("a listed sequence reaches its profiles and not the base")
    func listedReachesBoth() throws {
        let model = try makeModel()
        model.config.layers[0].bindings.append(tree())
        model.setAllProfiles(.key, key(), false)
        model.setProfile(.key, key(), "Home", true)
        model.updateActiveProfile()

        #expect(base(model).isEmpty)
        #expect(try own(model, "Work") == [tree()])
        #expect(try own(model, "Home") == [tree()])
    }

    @Test("a tick a key sequence clashes on is refused")
    func clashingTickIsRefused() throws {
        let model = try makeModel()
        var home = try model.core.profiles.read(name: "Home")
        home.layers = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [KeyBinding(combo: leader, lua: left)]
                )
            ]
        )
        try model.core.profiles.write(home)
        model.reload()
        model.config.layers[0].bindings.append(tree())
        model.setAllProfiles(.key, key(), false)
        let reading = try #require(model.keyReach(key()))
        #expect(reading.clashing == ["Home"])
        model.setProfile(.key, key(), "Home", true)
        #expect(model.keyReach(key())?.users.contains("Home") == false)
        model.updateActiveProfile()

        let stored = try model.core.profiles.read(name: "Home").layers
        let homeRows = stored?.layers.first?.bindings ?? []
        #expect(
            homeRows.contains { $0.lua == left && $0.combo == leader }
        )
        #expect(try own(model, "Home").isEmpty)
    }

    @Test("a re-recorded leader keeps the sequence's reach")
    func reRecordCarriesTheReach() throws {
        let model = try makeModel()
        model.config.layers[0].bindings.append(tree())
        model.setAllProfiles(.key, key(), false)
        model.setProfile(.key, key(), "Home", true)
        model.updateActiveProfile()

        let moved = "ctrl+alt+b"
        model.carrySequenceReach(
            layer: KeyLayer.defaultName,
            from: leader,
            to: moved
        )
        let at = try #require(
            model.config.layers[0].bindings.firstIndex(where: \.isSequence)
        )
        model.config.layers[0].bindings[at].combo = moved
        model.updateActiveProfile()

        #expect(base(model).isEmpty)
        #expect(try own(model, "Home") == [tree(moved)])
        #expect(try own(model, "Work") == [tree(moved)])
    }

    @Test("a profile's own sequence is edited on its own page")
    func ownSequenceEdits() throws {
        let model = try makeModel()
        var work = try model.core.profiles.read(name: "Work")
        work.layers = KeyLayerOverride(
            layers: [
                KeyLayer(name: KeyLayer.defaultName, bindings: [tree()])
            ]
        )
        try model.core.profiles.write(work)
        model.reload()
        let at = try #require(
            model.config.layers[0].bindings.firstIndex(where: \.isSequence)
        )
        model.config.layers[0].bindings[at].label = "Mine"
        model.updateActiveProfile()

        #expect(base(model).isEmpty)
        #expect(try own(model, "Work") == [tree(nil, "Mine")])
        #expect(try own(model, "Home").isEmpty)
    }
}
