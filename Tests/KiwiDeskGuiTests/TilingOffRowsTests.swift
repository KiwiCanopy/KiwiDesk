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

    @Test("the readouts narrate follows, on and off against an Off base")
    func threeStateReadouts() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        #expect(!model.tilingStartBase)
        let draft = model.config
        #expect(draft.appWide?.tilingStartGlobal == false)
        var on = draft
        on.settings.tiling.start = true
        on.settings.tiling.offHidesBorders = true
        on.settings.tiling.offHidesBars = true
        var off = draft
        off.settings.tiling.start = false
        off.settings.tiling.offHidesBorders = false
        off.settings.tiling.offHidesBars = false
        let follows = "follows All profiles · Off"
        for key in [
            BehaviourKey.tilingStart, .tilingOffHidesBorders,
            .tilingOffHidesBars,
        ] {
            let rows = { (old: GuiConfig, new: GuiConfig) in
                SettingsValueReadout.rows(
                    for: .behaviour(key),
                    old: old,
                    new: new
                )
            }
            let toOn = try #require(rows(draft, on).first)
            #expect(toOn.oldValue == follows)
            #expect(toOn.newValue == "On")
            let back = try #require(rows(off, draft).first)
            #expect(back.oldValue == "Off")
            #expect(back.newValue == follows)
        }
        // The follow names the value it resolves to.
        var onBase = draft
        onBase.appWide?.tilingStartGlobal = true
        let row = try #require(
            SettingsValueReadout.rows(
                for: .behaviour(.tilingStart),
                old: onBase,
                new: off
            ).first
        )
        #expect(row.oldValue == "follows All profiles · On")
    }

    @Test("the row reads the stored base the tables encode against")
    func rowReadsTheStoredBase() throws {
        let model = try makeModel()
        model.core.execute("set_tiling_start_global", args: [.bool(true)])
        #expect(model.core.appWide.tilingStartGlobal)
        #expect(!model.tilingStartOn)
        model.config.settings.tiling.start = true
        model.updateActiveProfile()
        // The tick moved the stored base the row showed.
        #expect(model.core.appWideSettled.tilingStartGlobal)
    }

    @Test("a live Save keeps a verb's session start it did not touch")
    func liveSaveKeepsTheSessionStart() throws {
        let model = try makeModel()
        model.core.execute("tiling.set_start", args: [.bool(true)])
        model.config.settings.resizeStep += 10
        model.updateActiveProfile()
        #expect(model.core.tiler.settings.tiling.start == true)
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

    @Test("each grey names what makes its row work, and links there")
    func greysLink() throws {
        LocalizationManager.shared.select("en")
        let bars = try #require(TilingOffWords.link(for: .noBarShows))
        #expect(bars.destination == .bars)
        #expect(bars.prose.contains(CrossReferenceRow.linkSlot))
        #expect(bars.prose.hasPrefix("Works when the Space Bar or App Bar"))
        let border = try #require(TilingOffWords.link(for: .focusBorderOff))
        #expect(border.destination == .gapsAndBorders)
        #expect(border.prose.contains(CrossReferenceRow.linkSlot))
        #expect(
            TilingOffWords.hover(border)
                == "Works when the focus border is on in Gaps & Borders."
        )
        #expect(TilingOffWords.link(for: .trackUnused) == nil)
    }

    @Test("the hide rows grey where they would hide nothing")
    func hideRowsGrey() throws {
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
        // An App Bar that shows keeps the row live on its own.
        let scrolling = try #require(
            TilingSettings.appBarPath(for: .scrolling)
        )
        config.settings[keyPath: scrolling].visibility = .always
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBars)) == nil
        )
        config.settings[keyPath: scrolling].visibility = .hidden
        config.settings.spaceBarStyle.visibility = .auto
        #expect(
            gates().inertReason(for: .behaviour(.tilingOffHidesBars)) == nil
        )
    }
}
