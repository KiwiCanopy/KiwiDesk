import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The checklist's other two binding names — the "used for" caption
/// and the save pill's reach row — read the localized door too
/// (#2111): the stored label is an English identifier.
@Suite("Binding names in the reach checklist (#2111)", .serialized)
@MainActor
struct BindingNameReachTests {
    private let stored = "Toggle display sticky"
    private let sticky = "KiwiDesk.toggle_display_sticky()"
    private let reload = "KiwiDesk.reload_config()"

    private func binding(_ combo: String) -> KeyBinding {
        KeyBinding(
            combo: combo,
            lua: sticky,
            kind: .navigation,
            label: stored
        )
    }

    /// Work (loaded) and Home (stored); `homeLayer`, when given,
    /// is Home's own default layer.
    private func makeModel(
        base: [KeyBinding],
        homeLayer: [KeyBinding]? = nil
    ) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: base)
        ]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        var home = profile("Home")
        if let homeLayer {
            home.layers = KeyLayerOverride(layers: [
                KeyLayer(name: KeyLayer.defaultName, bindings: homeLayer)
            ])
        }
        try core.profiles.write(home)
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

    private func localized(_ model: SettingsModel) -> String {
        let name = KeybindingCatalog.localizedLabel(
            for: stored,
            config: model.config
        )
        // Vacuity: the row's own name differs from the stored one.
        #expect(name != stored)
        return name
    }

    @Test("the used-for caption names the rival in the reader's language")
    func takerIsLocalized() throws {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        let model = try makeModel(
            base: [
                KeyBinding(
                    combo: "ctrl+alt+p",
                    lua: reload,
                    kind: .custom
                )
            ],
            homeLayer: [binding("ctrl+alt+p")]
        )
        let row = try #require(model.keyReach(key(reload)))
        let taker = try #require(row.takenBy["Home"])
        #expect(taker == localized(model))
    }

    @Test("the save pill's reach row names the binding localized")
    func diffRowIsLocalized() throws {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        let model = try makeModel(base: [binding("ctrl+alt+p")])
        let at = try #require(
            model.config.layers.firstIndex {
                $0.name == KeyLayer.defaultName
            }
        )
        model.config.layers[at].bindings[0].combo = "ctrl+alt+o"
        let rows = model.reachDiffRows().filter {
            $0.label.contains("Home")
        }
        #expect(!rows.isEmpty)
        let name = localized(model)
        #expect(rows.allSatisfy { $0.label.contains(name) })
        #expect(!rows.contains { $0.label.contains(stored) })
    }

    @Test("a binding storing no label is named after its command")
    func unlabelledNamesTheCommand() {
        LocalizationManager.shared.select("de")
        defer { LocalizationManager.shared.select(nil) }
        let config = GuiConfig()
        let unlabelled = KeyBinding(combo: "", lua: sticky)
        let name = KeybindingCatalog.localizedName(
            of: unlabelled,
            config: config
        )
        #expect(name != sticky)
        #expect(
            name
                == KeybindingCatalog.localizedLabel(
                    for: stored,
                    config: config
                )
        )
        let unknown = KeyBinding(combo: "", lua: "foo()")
        #expect(
            KeybindingCatalog.localizedName(of: unknown, config: config)
                == "foo()"
        )
    }
}
