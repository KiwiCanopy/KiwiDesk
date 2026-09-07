import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// What the one Liquid Glass row WRITES and SHOWS (#1307).
///
/// Nothing else can see either half. The census records one row
/// over three stored leaves, and a master that flips two of them
/// ships a switch whose whole claim — one finish across both
/// bars and the shortcuts panel — is false at the pixel on
/// whichever surface it missed. The `?` half matters for the
/// same reason: a boolean cannot show "two of three", so the
/// sentence is the only channel that state has.
@MainActor
@Suite("The Liquid Glass master")
struct LiquidGlassMasterTests {
    /// The default this suite reasons from (tests.md): all three
    /// ship OFF together, so an untouched config already agrees
    /// with what the row shows and the master never has to write
    /// to make that true. A panel defaulting ON would render
    /// glass beside a switch reading off.
    @Test("the shipped surfaces already agree")
    func shippedSurfacesAgree() {
        let settings = TilingSettings()
        #expect(settings.appBarStyle.liquidGlass == false)
        #expect(settings.spaceBarStyle.liquidGlass == false)
        #expect(settings.shortcutPanelLiquidGlass == false)
        #expect(
            LiquidGlassAgreement(settings: settings).differ
                == false
        )
    }

    @Test("the master writes all three surfaces")
    func masterFansOut() {
        for on in [true, false] {
            let model = makeTestModel()
            model.liquidGlassMaster.wrappedValue = on
            let settings = model.config.settings
            #expect(settings.appBarStyle.liquidGlass == on)
            #expect(settings.spaceBarStyle.liquidGlass == on)
            #expect(settings.shortcutPanelLiquidGlass == on)
        }
    }

    /// Both values of the choice, and the third leaf tested on
    /// its own: a guard that only ever flips all three at once
    /// is blind to a master that reads two of them.
    @Test("the master shows on only when all three are on")
    func masterShowsAllThree() {
        let model = makeTestModel()
        model.liquidGlassMaster.wrappedValue = true
        #expect(model.liquidGlassMaster.wrappedValue)
        model.config.settings.shortcutPanelLiquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
        model.config.settings.shortcutPanelLiquidGlass = true
        model.config.settings.spaceBarStyle.liquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
        model.config.settings.spaceBarStyle.liquidGlass = true
        model.config.settings.appBarStyle.liquidGlass = false
        #expect(model.liquidGlassMaster.wrappedValue == false)
    }

    /// The `?` predicate, at both its answers — and it is the
    /// SAME reading the row shows, so the switch and its
    /// explanation cannot contradict.
    @Test("divergence is seen only while they disagree")
    func divergenceSeen() {
        var settings = TilingSettings()
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.appBarStyle.liquidGlass = true
        settings.spaceBarStyle.liquidGlass = true
        settings.shortcutPanelLiquidGlass = true
        #expect(!LiquidGlassAgreement(settings: settings).differ)
        settings.spaceBarStyle.liquidGlass = false
        #expect(LiquidGlassAgreement(settings: settings).differ)
        #expect(
            !LiquidGlassAgreement(settings: settings).allOn
        )
    }

    /// A retired row is not a retired setting: both bar verbs
    /// still reach their leaves, which is what keeps #678 Phase
    /// 2's per-layout precedent standing.
    @Test("the two bar leaves stay Lua-reachable")
    func barLeavesStayLuaOnly() {
        #expect(
            SettingKey.appBar(.appBarLiquidGlass).placement
                == .luaOnly
        )
        #expect(
            SettingKey.spaceBar(.spaceBarLiquidGlass).placement
                == .luaOnly
        )
    }

    /// The census declaration the fan-out rests on: `masterWrites`
    /// is what books one edit as one change in the save pill, so
    /// a leaf missing here is a leaf the draft never reports.
    @Test("the master declares all three leaves")
    func masterDeclaresItsLeaves() throws {
        let leaves = try #require(
            SettingKey.masterWrites[
                .colours(.liquidGlassMaster)
            ]
        )
        #expect(
            leaves.sorted()
                == [
                    "settings.appBarStyle.liquidGlass",
                    "settings.shortcutPanelLiquidGlass",
                    "settings.spaceBarStyle.liquidGlass",
                ].sorted()
        )
    }
}
