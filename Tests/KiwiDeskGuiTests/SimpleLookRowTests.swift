import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's one look row (#2745 ruling): on Simple a look pick's
/// rows fold into "Changes to the look", whose ↺ takes the pick
/// back; Advanced keeps a row per setting. Main-actor spend: model
/// construction and a few diff walks.
@MainActor
@Suite("Simple look row")
struct SimpleLookRowTests {
    /// A model on `root` whose saved profile carries an authored
    /// origin and a per-layout App Bar indicator, then picks a
    /// bundled look naming the indicator — so the pick reaches past
    /// its keys — plus one edit no look paints.
    private func model(_ root: SettingsRoot) throws -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(root, to: defaults)
        let model = makeTestModel(defaults: defaults)
        var saved = model.config.settings
        saved.lookOrigin = ShelfLook(
            name: "Authored",
            style: [:],
            colors: [:],
            author: "Someone"
        )
        saved.monocle.appBar.activeIndicator = .outline
        model.cleanConfig.settings = saved
        model.config.settings = saved
        var look = try #require(
            model.core.bundledLooks.first {
                $0.match(saved) == .none
            }
        )
        look.style["app_bar.active_indicator"] = .string("edge_mark")
        // Every outer edge moved alike, so the pill narrates the
        // gap group's master rather than its members.
        var gapped = saved
        gapped.gapsGlobal.outer.top += 7
        gapped.gapsGlobal.outer.bottom += 7
        gapped.gapsGlobal.outer.left += 7
        gapped.gapsGlobal.outer.right += 7
        look.style["gap.global"] = try #require(
            LookKeys.extract(from: gapped, paths: ["gap.global"])["gap.global"]
        )
        model.applyLook(look)
        model.config.settings.spaceBarStyle.visibility =
            saved.spaceBarStyle.visibility == .hidden ? .always : .hidden
        return model
    }

    private func rows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model)
    }

    @Test("on Simple a pick's rows are one row, the rest their own")
    func simpleFolds() throws {
        let simple = try model(.simple)
        let rows = rows(simple)
        #expect(rows.filter { $0.revert == .lookChanges }.count == 1)
        // Its every reach is folded: the origin and the per-layout
        // indicator the pick cleared leave no row of their own.
        let keys = rows.map(\.key)
        #expect(!keys.contains(.colours(.lookOrigin)))
        #expect(!keys.contains(.layoutAppBar(.monocleAppBarActiveIndicator)))
        #expect(!keys.contains(.gaps(.outer)))
        // The bar's on/off is the one row left beside it.
        #expect(rows.count == 2)
        #expect(keys.contains(.kiwishelf(.visibility)))
    }

    @Test("on Advanced every setting keeps its row")
    func advancedKeepsRows() throws {
        let advanced = try model(.advanced)
        let rows = rows(advanced)
        let keys = rows.map(\.key)
        #expect(!rows.contains { $0.revert == .lookChanges })
        #expect(keys.contains(.colours(.lookOrigin)))
        #expect(keys.contains(.layoutAppBar(.monocleAppBarActiveIndicator)))
        #expect(keys.contains(.gaps(.outer)))
        #expect(keys.count > 3)
    }

    @Test("the look row's ↺ takes the pick back, and no other")
    func revertTakesTheLook() throws {
        let model = try model(.simple)
        let edited = model.config.settings.spaceBarStyle.visibility
        let row = try #require(
            rows(model).first { $0.revert == .lookChanges }
        )
        #expect(model.canRevert(row))
        #expect(!model.revertTakesGroup(row))
        model.revert(row)
        var expected = model.cleanConfig.settings
        expected.spaceBarStyle.visibility = edited
        #expect(model.config.settings == expected)
        #expect(rows(model).map(\.key) == [.kiwishelf(.visibility)])
    }

    @Test("the look row's jump stays on Simple")
    func jumpStays() throws {
        let model = try model(.simple)
        let row = try #require(
            rows(model).first { $0.revert == .lookChanges }
        )
        #expect(SimpleCoverage.draws(row, in: model))
        model.jump(to: row)
        #expect(model.showsSimple)
        #expect(model.nav.pendingReveal == nil)
    }
}
