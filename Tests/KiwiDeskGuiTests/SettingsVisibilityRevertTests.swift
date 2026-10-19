import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bar's visibility ↺ (#761, #792): each bar stores its own
/// value — the App Bar one per layout — so each row's ↺ takes back
/// its own value alone, whether or not the bars share an edge.
@MainActor
@Suite("Bar visibility revert (#761)")
struct SettingsVisibilityRevertTests {
    /// Every bar's value edited off `always`, both bars on the top
    /// edge.
    private func model() -> SettingsModel {
        var baseline = GuiConfig()
        baseline.settings.spaceBarStyle.setEdge(.top)
        baseline.settings.appBarStyle.setEdge(.top)
        var edited = baseline
        edited.settings.spaceBarStyle.visibility = .auto
        edited.settings.monocle.appBar.visibility = .hidden
        edited.settings.scrolling.appBar.visibility = .auto
        let model = makeTestModel()
        model.cleanConfig = baseline
        model.config = edited
        return model
    }

    private func revert(_ key: SettingKey, in model: SettingsModel) throws {
        let writer = try #require(SettingsRevertRegister.writers[key])
        writer.apply(model, nil)
    }

    @Test("The Space Bar's ↺ takes back its own value alone")
    func spaceBarRevertsAlone() throws {
        let model = model()
        try revert(.spaceBar(.spaceBarVisibility), in: model)
        let settings = model.config.settings
        #expect(settings.spaceBarStyle.visibility == .always)
        #expect(settings.monocle.appBar.visibility == .hidden)
        #expect(settings.scrolling.appBar.visibility == .auto)
    }

    @Test("A layout's App Bar ↺ takes back that layout's value alone")
    func layoutRevertsAlone() throws {
        let model = model()
        try revert(.layoutAppBar(.monocleAppBarVisibility), in: model)
        let settings = model.config.settings
        #expect(settings.monocle.appBar.visibility == .always)
        #expect(settings.scrolling.appBar.visibility == .auto)
        #expect(settings.spaceBarStyle.visibility == .auto)
    }
}
