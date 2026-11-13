import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Restore Defaults asks before it changes another profile (#3248):
/// "here" writes the edited profile alone, "every profile" resets the
/// seeded rows of all, whatever value each held, and rows the user
/// added stay in both. Work is loaded; Home and Travel are stored.
@Suite("Restore Defaults reaches as far as asked (#3248)", .serialized)
@MainActor
struct RestoreReachTests {
    private let lua = LuaAction(lua: "KiwiDesk.reload_config()", kind: .custom)
    private let other = LuaAction(
        lua: "KiwiDesk.focus(\"left\")",
        kind: .custom
    )
    private let added = GestureKey(.rightClick, [.control, .option])

    /// A seeded mouse gesture: the one each case moves off its seed.
    private var seeded: GestureKey {
        get throws {
            try #require(
                GestureSeeds.seeds.keys.sorted().first {
                    $0.input.device == .mouse
                }
            )
        }
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

    /// The issue's case: Work and Home bind the seed to one action,
    /// Travel to another; Work also added a row of its own.
    private func gestureModel(base: GestureMap = GestureMap())
        throws -> SettingsModel
    {
        let key = try seeded
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.gesture = base
        try core.guiConfigStore.save(config)
        var work = profile("Work")
        work.gesture = GestureMap([
            key: .bound(.run(lua)), added: .bound(.run(other)),
        ])
        try core.profiles.save(work)
        var home = profile("Home")
        home.gesture = GestureMap([key: .bound(.run(lua))])
        try core.profiles.write(home)
        var travel = profile("Travel")
        travel.gesture = GestureMap([key: .bound(.run(other))])
        try core.profiles.write(travel)
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func gesture(_ model: SettingsModel, _ name: String) throws
        -> GestureMap?
    {
        try model.core.profiles.read(name: name).gesture
    }

    @Test("who changed is the union across the card's seeded gestures")
    func whoChanged() throws {
        let model = try gestureModel()
        #expect(
            model.gestureRestoreChangedElsewhere(on: .mouse)
                == ["Home", "Travel"]
        )
        // A profile that only added rows has changed no seed.
        #expect(model.gestureRestoreChangedElsewhere(on: .trackpad) == [])
    }

    @Test("here resets Work alone; Home and Travel keep theirs")
    func gestureHere() throws {
        let key = try seeded
        let model = try gestureModel()
        model.restoreGestureDefaults(on: .mouse, reach: .here)
        model.updateActiveProfile()
        let work = try gesture(model, "Work")
        #expect(work?[key] == nil)
        #expect(work?[added] == .bound(.run(other)))
        #expect(try gesture(model, "Home")?[key] == .bound(.run(lua)))
        #expect(try gesture(model, "Travel")?[key] == .bound(.run(other)))
        #expect(model.core.guiConfigStore.load()?.gesture[key] == nil)
    }

    @Test("every profile resets every value, matching or not")
    func gestureEveryProfile() throws {
        let key = try seeded
        let model = try gestureModel()
        model.restoreGestureDefaults(on: .mouse, reach: .everyProfile)
        model.updateActiveProfile()
        for name in ["Work", "Home", "Travel"] {
            #expect(try gesture(model, name)?[key] == nil, "\(name)")
        }
        #expect(try gesture(model, "Work")?[added] == .bound(.run(other)))
        #expect(model.core.guiConfigStore.load()?.gesture[key] == nil)
    }

    /// A shared base off the seed: the followers count as changed,
    /// and "here" leaves the base and them alone.
    @Test("here never moves a shared base the others follow")
    func gestureHereKeepsTheBase() throws {
        let key = try seeded
        let model = try gestureModel(
            base: GestureMap([key: .bound(.run(other))])
        )
        model.restoreGestureDefaults(on: .mouse, reach: .here)
        model.updateActiveProfile()
        #expect(
            model.core.guiConfigStore.load()?.gesture[key]
                == .bound(.run(other))
        )
        let work = try #require(model.gestureReach(key.spelling))
        #expect(work.users == ["Work"])
        #expect(try gesture(model, "Home")?[key] == .bound(.run(lua)))
    }

    // MARK: - Shortcuts

    private let custom = "ctrl+alt+shift+f12"

    private func keyID(_ row: KeyBinding) -> String {
        RuleReachTable<String>.keyID(layer: KeyLayer.defaultName, lua: row.lua)
    }

    /// gui.json holds the seed this Mac would get; Work and Home move
    /// one seeded row to a chord of their own, Travel follows the base.
    private func shortcutModel() throws -> (SettingsModel, KeyBinding) {
        let core = makeTestCore()
        let probe = makeTestModel(core: core)
        probe.config.spaces = [SpaceID("1")]
        let shipped = probe.shippedDefaults(on: GuiConfig().shortcutBase)
        let seed = try #require(shipped.first)
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: shipped)
        ]
        try core.guiConfigStore.save(config)
        var moved = seed
        moved.combo = custom
        for name in ["Work", "Home"] {
            var own = profile(name)
            own.layers = KeyLayerOverride(
                layers: [
                    KeyLayer(name: KeyLayer.defaultName, bindings: [moved])
                ],
                removed: [KeyLayer.defaultName: [seed.combo]]
            )
            if name == "Work" {
                try core.profiles.save(own)
            } else {
                try core.profiles.write(own)
            }
        }
        try core.profiles.write(profile("Travel"))
        let model = makeTestModel(core: core)
        model.reload()
        return (model, seed)
    }

    private func combo(
        _ model: SettingsModel,
        _ name: String,
        _ row: KeyBinding
    )
        throws -> String?
    {
        let base = model.core.guiConfigStore.load()?.layers ?? []
        let layers =
            try model.core.profiles.read(name: name).layers?
            .resolved(onto: base) ?? base
        return RuleReachTable<String>.combos(layers)[keyID(row)]
    }

    @Test("Shortcuts: Home changed the seeded rows too, Travel did not")
    func shortcutsWhoChanged() throws {
        let (model, _) = try shortcutModel()
        #expect(model.shortcutsRestoreChangedElsewhere == ["Home"])
    }

    @Test("Shortcuts here restores Work alone")
    func shortcutsHere() throws {
        let (model, seed) = try shortcutModel()
        model.resetShortcutsToDefaults(reach: .here)
        model.updateActiveProfile()
        #expect(try combo(model, "Work", seed) == seed.combo)
        #expect(try combo(model, "Home", seed) == custom)
        #expect(try combo(model, "Travel", seed) == seed.combo)
    }

    @Test("Shortcuts every profile restores Home too")
    func shortcutsEveryProfile() throws {
        let (model, seed) = try shortcutModel()
        model.resetShortcutsToDefaults(reach: .everyProfile)
        model.updateActiveProfile()
        for name in ["Work", "Home", "Travel"] {
            #expect(try combo(model, name, seed) == seed.combo, "\(name)")
        }
    }

    @Test("who else changed reads by name, then as a count")
    func changedInLadder() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        #expect(
            RestoreReachWords.changedIn(["Home", "Travel"])
                == "Changed in Home, Travel."
        )
        #expect(
            RestoreReachWords.changedIn(["A", "B", "C"])
                == "Changed in profiles: 3"
        )
    }
}
