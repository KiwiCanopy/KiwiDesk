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
    /// Both bars set to auto on a draft with the App Bar on the
    /// bottom where `split`, over a baseline split where
    /// `splitInBaseline` (by default as the draft).
    private func model(
        split: Bool,
        splitInBaseline: Bool? = nil
    ) -> SettingsModel {
        var baseline = GuiConfig()
        baseline.settings.spaceBarStyle.setEdge(.top)
        baseline.settings.appBarStyle.setEdge(
            (splitInBaseline ?? split) ? .bottom : .top
        )
        var edited = baseline
        edited.settings.appBarStyle.setEdge(split ? .bottom : .top)
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

    @Test("Split in the draft alone, the ↺ takes back its own bar")
    func draftSplitRevertsOne() throws {
        let model = model(split: true, splitInBaseline: false)
        try revert(.spaceBar(.spaceBarVisibility), in: model)
        #expect(model.config.settings.spaceBarStyle.visibility == .always)
        #expect(model.config.settings.appBarStyle.visibility == .auto)
    }

    @Test("Apart, each bar's ↺ takes back its own bar")
    func apartRevertsOne() throws {
        let model = model(split: true)
        try revert(.appBar(.appBarVisibility), in: model)
        #expect(model.config.settings.appBarStyle.visibility == .always)
        #expect(model.config.settings.spaceBarStyle.visibility == .auto)
    }
}
