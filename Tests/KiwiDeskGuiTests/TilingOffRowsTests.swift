import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Tiling off rows (#3089), draft to files: each row reads its
/// profile's own value over the shared one, narrates follows, on
/// or off, writes the shared value through All profiles and greys
/// with its reason where it would hide nothing. Main-actor spend:
/// one test model per case, no source scan.
@Suite("Tiling off rows (#3089)", .serialized)
@MainActor
struct TilingOffRowsTests {
    private typealias Table = RuleReachTable<Bool>

    /// Work is loaded and follows every shared value; the shared
    /// start value is Off.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        core.setAppWide(persisting: true) { $0.tilingStartGlobal = false }
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

    private func readout(
        _ key: BehaviourKey,
        _ old: TilingToggleSettings,
        _ new: TilingToggleSettings
    ) -> [SettingsDiffRow] {
        var before = GuiConfig()
        before.settings.tiling = old
        var after = GuiConfig()
        after.settings.tiling = new
        return SettingsValueReadout.rows(
            for: .behaviour(key),
            old: before,
            new: after
        )
    }

    @Test("the readouts narrate follows, on and off against an Off base")
    func threeStateReadouts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        #expect(!model.tilingStartBase)
        #expect(!model.tilingStartOn)
        let follows = TilingToggleSettings()
        var on = follows
        on.start = true
        on.offHidesBorders = true
        on.offHidesBars = true
        var off = follows
        off.start = false
        off.offHidesBorders = false
        off.offHidesBars = false
        for key in [
            BehaviourKey.tilingStart, .tilingOffHidesBorders,
            .tilingOffHidesBars,
        ] {
            let toOn = try #require(readout(key, follows, on).first)
            #expect(toOn.oldValue == "Same as all profiles")
            #expect(toOn.newValue == "On")
            let toOff = try #require(readout(key, follows, off).first)
            #expect(toOff.newValue == "Off")
            let back = try #require(readout(key, off, follows).first)
            #expect(back.newValue == "Same as all profiles")
        }
    }

    @Test("the loaded page follows; its switch reads the shared value")
    func pageFollows() throws {
        let model = try makeModel()
        #expect(model.config.settings.tiling.start == nil)
        let row = try #require(model.tilingStartReach())
        #expect(row.shared)
        model.config.settings.tiling.offHidesBars = true
        #expect(model.tilingOffHidesOn(Table.offHidesBarsKey))
        #expect(!model.tilingOffHidesOn(Table.offHidesBordersKey))
    }

    @Test("a live Save at All profiles writes the base, not the file")
    func sharedSaveWritesTheBase() throws {
        let model = try makeModel()
        model.config.settings.tiling.start = true
        model.updateActiveProfile()
        let core = model.core
        #expect(core.appWide.tilingStartGlobal)
        #expect(core.guiConfigStore.load()?.appWide?.tilingStartGlobal == true)
        #expect(
            try core.profiles.read(name: "Work").settings.tiling.start == nil
        )
        #expect(core.tiler.settings.tiling.start == nil)
        #expect(!core.isTilingOff(SpaceID("1")))
    }

    @Test("ticking Work alone writes its own value and keeps the base")
    func listedSaveWritesTheFile() throws {
        let model = try makeModel()
        let key = Table.offHidesBordersKey
        model.setAllProfiles(.tilingOffHides, key, false)
        model.setProfile(.tilingOffHides, key, "Home", false)
        model.config.settings.tiling.offHidesBorders = true
        model.updateActiveProfile()
        let core = model.core
        #expect(!core.appWide.tilingOffHidesBorders)
        let work = try core.profiles.read(name: "Work")
        #expect(work.settings.tiling.offHidesBorders == true)
        let home = try core.profiles.read(name: "Home")
        #expect(home.settings.tiling.offHidesBorders == nil)
    }

    @Test("the hide rows grey where they would hide nothing")
    func hideRowsGrey() {
        var config = GuiConfig()
        let gates = { ShortcutsGates(config: config) }
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBars)) == nil
        )
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBorders))
                == nil
        )
        config.settings.borderStyle.enabled = false
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBorders))
                == .focusBorderOff
        )
        config.settings.spaceBarStyle.visibility = .hidden
        for mode in LayoutMode.allCases {
            guard let path = TilingSettings.appBarPath(for: mode) else {
                continue
            }
            config.settings[keyPath: path].visibility = .hidden
        }
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBars))
                == .noBarShows
        )
        config.settings.spaceBarStyle.visibility = .auto
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBars)) == nil
        )
    }
}
