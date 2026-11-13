import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Shortcuts' Restore… across profiles (#3248 ▸ Amendment): "here"
/// writes the edited profile alone, "every profile" restores the
/// seed rows every profile shares, and a row a profile's own Spaces
/// or resize step spell otherwise stays that profile's. Work is
/// loaded; Home and Travel are stored.
@Suite("Shortcuts' Restore reaches as far as asked (#3248)", .serialized)
@MainActor
struct RestoreReachShortcutTests {
    private let custom = "ctrl+alt+shift+f12"
    /// Where Home moves a second seed Work keeps.
    private let elsewhere = "ctrl+alt+shift+f11"
    private let mine = KeyBinding(
        combo: "",
        lua: "KiwiDesk.reload_config()",
        kind: .custom
    )

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func keyID(_ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: KeyLayer.defaultName, lua: lua)
    }

    private struct Desk {
        let model: SettingsModel
        let seed: KeyBinding
        let kept: KeyBinding
    }

    /// gui.json holds the seed this Mac would get; Work and Home move
    /// one seeded row to a chord of their own, and with `ownRow` each
    /// also holds a row of its own on that row's seeded chord. Travel
    /// follows the base, or with `travel` holds its own seed for
    /// those Spaces and that resize step. With `homeMoves` off, Home
    /// follows the base too.
    private func desk(
        ownRow: Bool = false,
        homeMoves: Bool = true,
        travel: (spaces: [SpaceID], step: CGFloat)? = nil
    ) throws -> Desk {
        let core = makeTestCore()
        let probe = makeTestModel(core: core)
        probe.config.spaces = [SpaceID("1")]
        let base = GuiConfig().shortcutBase
        let shipped = probe.shippedDefaults(on: base)
        let seed = try #require(shipped.first)
        let kept = try #require(shipped.dropFirst().first)
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: shipped)
        ]
        try core.guiConfigStore.save(config)
        var moved = seed
        moved.combo = custom
        var own = mine
        own.combo = seed.combo
        var homeMoved = kept
        homeMoved.combo = elsewhere
        for name in homeMoves ? ["Work", "Home"] : ["Work"] {
            let home = name == "Home"
            var file = profile(name)
            file.layers = KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: (ownRow ? [moved, own] : [moved])
                            + (home ? [homeMoved] : [])
                    )
                ],
                removed: [
                    KeyLayer.defaultName: [seed.combo]
                        + (home ? [kept.combo] : [])
                ]
            )
            if name == "Work" {
                try core.profiles.save(file)
            } else {
                try core.profiles.write(file)
            }
        }
        if !homeMoves { try core.profiles.write(profile("Home")) }
        var file = profile("Travel")
        if let travel {
            file.spaces = travel.spaces
            file.settings.resizeStep = travel.step
            let page = Set(shipped.map(\.lua))
            let theirs = probe.shippedDefaults(
                on: base,
                spaces: travel.spaces,
                resizeStep: travel.step
            )
            .filter { !page.contains($0.lua) }
            file.layers = KeyLayerOverride(layers: [
                KeyLayer(name: KeyLayer.defaultName, bindings: theirs)
            ])
        }
        try core.profiles.write(file)
        let model = makeTestModel(core: core)
        model.reload()
        return Desk(model: model, seed: seed, kept: kept)
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

    @Test("Home changed the seeded rows too, Travel did not")
    func whoChanged() throws {
        #expect(try desk().model.shortcutsRestoreChangedElsewhere == ["Home"])
    }

    @Test("here restores Work alone")
    func here() throws {
        let desk = try desk()
        desk.model.resetShortcutsToDefaults(reach: .here)
        desk.model.updateActiveProfile()
        let key = keyID(desk.seed.lua)
        #expect(try combos(desk.model, "Work")[key] == desk.seed.combo)
        #expect(try combos(desk.model, "Home")[key] == custom)
        #expect(
            try combos(desk.model, "Home")[keyID(desk.kept.lua)] == elsewhere
        )
        #expect(try combos(desk.model, "Travel")[key] == desk.seed.combo)
    }

    @Test("every profile restores Home too")
    func everyProfile() throws {
        let desk = try desk()
        desk.model.resetShortcutsToDefaults(reach: .everyProfile)
        desk.model.updateActiveProfile()
        let key = keyID(desk.seed.lua)
        for name in ["Work", "Home", "Travel"] {
            #expect(
                try combos(desk.model, name)[key] == desk.seed.combo,
                "\(name)"
            )
        }
        // A seed Work never moved is restored where Home moved it.
        #expect(
            try combos(desk.model, "Home")[keyID(desk.kept.lua)]
                == desk.kept.combo
        )
    }

    /// The row the restore drops off Work's page sits on a seeded
    /// chord, and Home holds the same row: "here" leaves it out of
    /// Work alone, never out of Home by match.
    @Test("a dropped row leaves the edited profile alone")
    func droppedRowStaysElsewhere() throws {
        let desk = try desk(ownRow: true)
        desk.model.resetShortcutsToDefaults(reach: .here)
        desk.model.updateActiveProfile()
        let key = keyID(mine.lua)
        #expect(try combos(desk.model, "Work")[key] == nil)
        #expect(try combos(desk.model, "Home")[key] == desk.seed.combo)
    }

    /// Travel's resize rows are its own step's seed: no change, so it
    /// is not asked about, and "every profile" leaves them be.
    @Test("a row a profile's own step spells is that profile's")
    func ownStepIsKept() throws {
        let desk = try desk(travel: ([SpaceID("1")], 30))
        #expect(desk.model.shortcutsRestoreChangedElsewhere == ["Home"])
        desk.model.resetShortcutsToDefaults(reach: .everyProfile)
        desk.model.updateActiveProfile()
        let travel = try combos(desk.model, "Travel")
        let grow = keyID("KiwiDesk.resize(\"x\", 30)")
        #expect(travel[grow] == "option+command+2")
        #expect(travel[keyID("KiwiDesk.resize(\"x\", 50)")] == nil)
    }

    /// Travel's digit rows are its own Spaces' seed, the same.
    @Test("a row a profile's own Spaces spell is that profile's")
    func ownSpacesAreKept() throws {
        let desk = try desk(travel: ([SpaceID("2")], 50))
        #expect(desk.model.shortcutsRestoreChangedElsewhere == ["Home"])
        desk.model.resetShortcutsToDefaults(reach: .everyProfile)
        desk.model.updateActiveProfile()
        let travel = try combos(desk.model, "Travel")
        #expect(travel[keyID("KiwiDesk.focus_space(\"2\")")] != nil)
        #expect(travel[keyID("KiwiDesk.focus_space(\"1\")")] == nil)
    }

    /// Nobody else changed a seed, and the row the restore drops is
    /// Work's alone: the restore stages no reach of its own.
    @Test("a restore nobody else shares stages no reach")
    func unsharedRestoreStagesNothing() throws {
        let desk = try desk(ownRow: true, homeMoves: false)
        #expect(desk.model.shortcutsRestoreChangedElsewhere == [])
        desk.model.resetShortcutsToDefaults(reach: .here)
        #expect(desk.model.reachEdits.isEmpty)
    }

    /// A row added in this draft on a seeded chord is in no file: the
    /// restore drops it from the page and stages no removal for it.
    @Test("a draft-only row the restore drops stages nothing")
    func draftRowStagesNothing() throws {
        let desk = try desk(homeMoves: false)
        var row = mine
        row.combo = desk.seed.combo
        let index = try #require(
            desk.model.config.layers.firstIndex {
                $0.name == KeyLayer.defaultName
            }
        )
        desk.model.config.layers[index].bindings.append(row)
        desk.model.resetShortcutsToDefaults(reach: .here)
        #expect(desk.model.reachEdits.isEmpty)
    }

    /// "Every profile" takes Home's own row on the chord its seed
    /// takes back; the dialog's count names it before the Save does.
    @Test("the count of rows other profiles lose matches the Save")
    func lostElsewhereIsCounted() throws {
        #expect(try desk().model.shortcutsRestoreLostElsewhere == 0)
        let desk = try desk(ownRow: true)
        #expect(desk.model.shortcutsRestoreLostElsewhere == 1)
        let key = keyID(mine.lua)
        #expect(try combos(desk.model, "Home")[key] == desk.seed.combo)
        desk.model.resetShortcutsToDefaults(reach: .everyProfile)
        desk.model.updateActiveProfile()
        #expect(try combos(desk.model, "Home")[key] == nil)
    }
}
