import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Simple's one look row (#2745 ruling): on Simple a look's rows
/// fold into "Changes to the look", whose ↺ takes them all back;
/// Advanced keeps a row per setting. Main-actor spend: model
/// construction and a few diff walks.
@MainActor
@Suite("Simple look row")
struct SimpleLookRowTests {
    /// A model on `root` wearing the first bundled look that moves
    /// more than one look row, plus one edit no look paints.
    private func model(_ root: SettingsRoot) throws -> SettingsModel {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(root, to: defaults)
        let model = makeTestModel(defaults: defaults)
        let clean = model.config.settings
        let look = try #require(
            model.core.bundledLooks.first { look in
                model.config.settings = clean
                model.applyLook(look)
                return SettingsDiffRowSource.rows(
                    for: model,
                    foldingLook: false
                ).filter(SettingsDiffRowSource.foldsIntoLook).count > 1
            }
        )
        model.config.settings = clean
        model.applyLook(look)
        model.config.settings.spaceBarStyle.visibility =
            clean.spaceBarStyle.visibility == .hidden ? .always : .hidden
        return model
    }

    /// The rows no look paints.
    private func others(_ rows: [SettingsDiffRow]) -> [String] {
        rows.filter { !SettingsDiffRowSource.foldsIntoLook($0) }
            .filter { $0.revert != .lookChanges }.map(\.id)
    }

    private func rows(_ model: SettingsModel) -> [SettingsDiffRow] {
        SettingsDiffRowSource.rows(for: model)
    }

    @Test("on Simple a look's rows are one row, the rest their own")
    func simpleFolds() throws {
        let model = try model(.simple)
        let rows = rows(model)
        #expect(rows.filter { $0.revert == .lookChanges }.count == 1)
        #expect(!rows.contains(where: SettingsDiffRowSource.foldsIntoLook))
        #expect(!others(rows).isEmpty)
        // The row stands for more than one setting.
        #expect(SettingsDiffRowSource.lookMembers(of: model).count > 1)
    }

    @Test("on Advanced every setting keeps its row")
    func advancedKeepsRows() throws {
        let model = try model(.advanced)
        let rows = rows(model)
        #expect(!rows.contains { $0.revert == .lookChanges })
        #expect(
            rows.filter(SettingsDiffRowSource.foldsIntoLook).count > 1
        )
    }

    @Test("the look row's ↺ takes back every look change, and no other")
    func revertTakesTheLook() throws {
        let model = try model(.simple)
        let before = rows(model)
        let row = try #require(before.first { $0.revert == .lookChanges })
        #expect(model.canRevert(row))
        #expect(!model.revertTakesGroup(row))
        model.revert(row)
        #expect(SettingsDiffRowSource.lookMembers(of: model).isEmpty)
        #expect(
            LookKeys.extract(from: model.config.settings)
                == LookKeys.extract(from: model.cleanConfig.settings)
        )
        #expect(
            ColorPaletteKeys.extract(from: model.config.settings)
                == ColorPaletteKeys.extract(from: model.cleanConfig.settings)
        )
        // The bar's on/off stays edited.
        #expect(others(rows(model)) == others(before))
        #expect(!others(before).isEmpty)
    }

    @Test("the look row's jump stays on Simple")
    func jumpStays() throws {
        let model = try model(.simple)
        let row = try #require(rows(model).first { $0.revert == .lookChanges })
        #expect(SimpleCoverage.draws(row, in: model))
        model.jump(to: row)
        #expect(model.showsSimple)
        #expect(model.nav.pendingReveal == nil)
    }
}
