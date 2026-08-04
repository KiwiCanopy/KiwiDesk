import CoreGraphics
import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The per-setting draft diff behind the header's "N unsaved
/// changes" count (#678 turn 9). Two nets: the diff counts what
/// actually changed (and agrees with the dirty flag by
/// construction), and EVERY leaf a `GuiConfig` can hold resolves
/// to a census key — the forget-proofing for a new model field,
/// which would otherwise fall out of the count silently.
@Suite("Settings draft diff")
struct SettingsDraftDiffTests {
    /// Seeded like `SettingKeyModelParityTests`: every override
    /// dictionary carries one element so the walk can descend.
    private func seeded() -> GuiConfig {
        var config = GuiConfig()
        config.settings.gapsOverride["1"] = Gaps()
        config.settings.spaceIcons["1"] = "star"
        config.settings.placementOverride["1"] = .first
        config.settings.bsp.override["1"] = BspOverride()
        config.settings.stack.override["1"] = StackOverride()
        config.settings.scrolling.override["1"] =
            ScrollingOverride()
        config.settings.grid.override["1"] = GridOverride()
        config.settings.monocle.override["1"] =
            MonocleOverride()
        config.settings.track.override["1"] = TrackOverride()
        config.spaces = ["work"]
        config.spaceModes = ["work": .grid]
        config.appRules = ["Safari": "web"]
        config.spacePins = ["work": "fp"]
        config.mainSpaces = ["work"]
        config.fallbackSpace = "work"
        config.floatRules = ["Info"]
        config.ignoreRules = ["Helper"]
        config.profileBindings = [1: "Desk"]
        return config
    }

    @Test("equal configs diff to zero")
    func equalIsZero() {
        let config = seeded()
        let diff = SettingsDraftDiff.between(
            config: config,
            cleanConfig: config
        )
        #expect(diff.total == 0)
        #expect(diff.changedSettings.isEmpty)
        #expect(!diff.luaChanged)
    }

    @Test("one setting changed counts once, as its own key")
    func oneSettingCountsOnce() {
        let clean = seeded()
        var edited = clean
        // A per-space gap override is ONE census setting
        // (`settings.gapsOverride[space]`) with many leaves —
        // the collapse this diff exists to make.
        edited.settings.gapsOverride["1"]?.outer.top = 20
        edited.settings.gapsOverride["1"]?.outer.bottom = 20
        let diff = SettingsDraftDiff.between(
            config: edited,
            cleanConfig: clean
        )
        #expect(diff.total == 1)
        #expect(diff.unattributed.isEmpty)
        #expect(
            diff.changedSettings
                == [.gaps(.perSpaceOverride)]
        )
    }

    /// Per-edge gaps are their own census rows, so a top+bottom
    /// edit is honestly TWO changed settings — the collapse
    /// above must not over-collapse siblings.
    @Test("sibling settings do not collapse")
    func siblingsStayDistinct() {
        let clean = seeded()
        var edited = clean
        edited.settings.gapsGlobal.outer.top = 20
        edited.settings.gapsGlobal.outer.bottom = 20
        let diff = SettingsDraftDiff.between(
            config: edited,
            cleanConfig: clean
        )
        #expect(diff.total == 2)
        #expect(diff.unattributed.isEmpty)
        #expect(
            diff.changedSettings.allSatisfy {
                $0.placement.area == .gapsAndBorders
            }
        )
    }

    @Test("distinct settings count separately")
    func distinctSettingsAddUp() {
        let clean = seeded()
        var edited = clean
        edited.settings.minWindowSize = 420
        edited.settings.borderStyle.width = 9
        edited.spaces = ["work", "notes"]
        let diff = SettingsDraftDiff.between(
            config: edited,
            cleanConfig: clean
        )
        #expect(diff.total == 3)
        #expect(diff.unattributed.isEmpty)
    }

    @Test("an edited init.lua counts as one entry")
    func luaCountsOnce() {
        let config = seeded()
        let diff = SettingsDraftDiff.between(
            config: config,
            cleanConfig: config,
            luaSource: "kiwi.gap(8)",
            cleanLuaSource: ""
        )
        #expect(diff.luaChanged)
        #expect(diff.total == 1)
    }

    /// The forget-proof net: every leaf the walk can reach in a
    /// fully seeded config resolves to a census key. A new
    /// `GuiConfig` or `TilingSettings` field lands here before
    /// its census row exists and reds — the count must never
    /// silently exclude a settable field. (The walk refusing to
    /// descend an EMPTY dictionary is the parity suite's
    /// concern; the seeding above keeps this one total.)
    @Test("every reachable leaf resolves to a census key")
    func everyLeafIsAttributed() {
        // Diffing the fully seeded config against a DEFAULT one
        // flips every seeded leaf, driving each through
        // attribution.
        let diff = SettingsDraftDiff.between(
            config: GuiConfig(),
            cleanConfig: seeded()
        )
        #expect(!diff.changedSettings.isEmpty)
        #expect(
            diff.unattributed.isEmpty,
            Comment(
                rawValue:
                    "unattributed paths: "
                    + diff.unattributed.joined(separator: ", ")
            )
        )
    }
}
