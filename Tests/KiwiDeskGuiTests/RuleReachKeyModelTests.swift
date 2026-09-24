import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Shortcut rows' checklist, draft to files (#1393): the reach of
/// one action per layer, written through the same Save as App Rules.
@Suite("Rule reach, shortcut rows (#1393)", .serialized)
@MainActor
struct RuleReachKeyModelTests {
    private let focus = "KiwiDesk.focus(\"left\")"
    private let reload = "KiwiDesk.reload_config()"

    /// gui.json binds alt+h to focus left; Work (loaded) adds its
    /// own reload on ctrl+alt+r and a layer of its own; Home is
    /// stored.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "alt+h", lua: focus, kind: .navigation)
                ]
            )
        ]
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.layers = KeyLayerOverride(layers: [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "ctrl+alt+r", lua: reload, kind: .custom)
                ]
            ),
            KeyLayer(name: "office"),
        ])
        try core.profiles.save(work)
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

    private func key(_ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: KeyLayer.defaultName, lua: lua)
    }

    private func combos(_ model: SettingsModel, _ name: String) throws
        -> [String: String]
    {
        let base = model.core.guiConfigStore.load()?.layers ?? []
        let layers =
            try model.core.profiles.read(name: name).layers?
            .resolved(onto: base) ?? base
        return RuleReachTable<String>.combos(layers)
    }

    @Test("The loaded page shows its own shortcut, listed as its own")
    func ownShortcutIsListed() throws {
        let model = try makeModel()
        #expect(
            RuleReachTable<String>.combos(model.config.layers)[key(reload)]
                == "ctrl+alt+r"
        )
        let row = try #require(model.keyReach(key(reload)))
        #expect(!row.shared && row.users == ["Work"])
        #expect(try #require(model.keyReach(key(focus))).shared)
    }

    @Test("Ticking Home writes Work's own shortcut into Home's file")
    func tickHome() throws {
        let model = try makeModel()
        model.setProfile(.key, key(reload), "Home", true)
        model.updateActiveProfile()

        #expect(try combos(model, "Home")[key(reload)] == "ctrl+alt+r")
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(RuleReachTable<String>.combos(base)[key(reload)] == nil)
    }

    @Test("Remove from Work leaves Work out of a shared shortcut")
    func removeHereLeavesOut() throws {
        let model = try makeModel()
        model.recordRemoval(.key, key(focus), .here)
        let at = try #require(
            model.config.layers.firstIndex { $0.name == KeyLayer.defaultName }
        )
        model.config.layers[at].bindings.removeAll { $0.lua == focus }
        model.updateActiveProfile()

        #expect(try combos(model, "Work")[key(focus)] == nil)
        #expect(try combos(model, "Home")[key(focus)] == "alt+h")
        // The shared row stays; Work's file marks it out; Home's
        // file is not touched.
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(RuleReachTable<String>.combos(base)[key(focus)] == "alt+h")
        let work = try model.core.profiles.read(name: "Work").layers
        #expect(work?.removed[KeyLayer.defaultName] == ["alt+h"])
        #expect(try model.core.profiles.read(name: "Home").layers == nil)
    }

    @Test("Remove from Home on its stored page leaves Home out")
    func storedRemoveHereLeavesOut() throws {
        let model = try makeModel()
        model.selectEditTarget("Home")
        model.recordRemoval(.key, key(focus), .here)
        let at = try #require(
            model.config.layers.firstIndex { $0.name == KeyLayer.defaultName }
        )
        model.config.layers[at].bindings.removeAll { $0.lua == focus }
        model.saveEditedProfile()

        #expect(try combos(model, "Home")[key(focus)] == nil)
        #expect(try combos(model, "Work")[key(focus)] == "alt+h")
        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(RuleReachTable<String>.combos(base)[key(focus)] == "alt+h")
    }

    @Test("A layer only Work carries stays out of gui.json")
    func ownLayerStaysOut() throws {
        let model = try makeModel()
        #expect(model.config.layers.contains { $0.name == "office" })
        #expect(!model.sidecarConfig.layers.contains { $0.name == "office" })
        #expect(
            RuleReachTable<String>.combos(model.sidecarConfig.layers)[
                key(reload)
            ] == nil
        )
    }

    @Test("A failed Save keeps a Work-only new shortcut out of the base")
    func failedSaveKeepsListedOut() throws {
        let model = try makeModel()
        let lua = "KiwiDesk.toggle_float()"
        let at = try #require(
            model.config.layers.firstIndex { $0.name == KeyLayer.defaultName }
        )
        model.config.layers[at].bindings.append(
            KeyBinding(combo: "ctrl+alt+f", lua: lua, kind: .custom)
        )
        model.setAllProfiles(.key, key(lua), false)
        // The rule write reads Home (ticked onto Work's reload), and
        // Home cannot be read — the tiling save never touches it.
        model.setProfile(.key, key(reload), "Home", true)
        model.config.ignoreRules = ["com.example.ignored"]
        let url = try model.core.profiles.fileURL(name: "Home")
        try Data("not json".utf8).write(to: url)

        model.updateActiveProfile()

        let base = model.core.guiConfigStore.load()?.layers ?? []
        #expect(RuleReachTable<String>.combos(base)[key(lua)] == nil)
    }
}
