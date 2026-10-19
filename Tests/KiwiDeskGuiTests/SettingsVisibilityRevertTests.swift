import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bar's visibility ↺ (#761, #792): while the bars share an edge
/// the door writes both, so the ↺ takes the pair back together; on
/// two edges each bar's ↺ takes back its own bar alone.
@MainActor
@Suite("Bar visibility revert (#761)")
struct SettingsVisibilityRevertTests {
    private func model(split: Bool) -> SettingsModel {
        var baseline = GuiConfig()
        baseline.settings.spaceBarStyle.setEdge(.top)
        baseline.settings.appBarStyle.setEdge(split ? .bottom : .top)
        var edited = baseline
        edited.settings.setVisibility(.auto, of: .space)
        edited.settings.setVisibility(.auto, of: .app)
        let model = makeTestModel()
        model.cleanConfig = baseline
        model.config = edited
        return model
    }

    private func revert(_ key: SettingKey, in model: SettingsModel) throws {
        let writer = try #require(SettingsRevertRegister.writers[key])
        writer.apply(model, nil)
    }

    @Test("Linked, one bar's ↺ takes both back")
    func linkedRevertsThePair() throws {
        let model = model(split: false)
        try revert(.appBar(.appBarVisibility), in: model)
        #expect(model.config.settings.spaceBarStyle.visibility == .always)
        #expect(model.config.settings.appBarStyle.visibility == .always)
    }

    @Test("Apart, each bar's ↺ takes back its own bar")
    func apartRevertsOne() throws {
        let model = model(split: true)
        try revert(.appBar(.appBarVisibility), in: model)
        #expect(model.config.settings.appBarStyle.visibility == .always)
        #expect(model.config.settings.spaceBarStyle.visibility == .auto)
    }
}
