import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bar menu's App Rules… on a window that floats on a guess lands
/// on the Automatic floating card (#2173), the escape its refusal
/// names; so does an app with a Tile rule.
@Suite("Automatic floating landing (#2173)", .serialized)
@MainActor
struct AutoFloatLandingTests {
    private let app = "com.valvesoftware.steam"

    private func model() -> SettingsModel {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    @Test("a Tile rule or a guessed float lands on Automatic floating")
    func landsOnTheCard() {
        let card = SettingsCatalog.appRules.automaticList
        let ruled = model()
        ruled.config.tileRules = [app]
        #expect(AppRulesSection.card(holding: app, in: ruled) == card)
        let guessed = model()
        let id = WindowID(4_201)
        guessed.core.state.windows.upsert(
            ManagedWindow(
                id: id,
                pid: 4_201,
                appName: "Steam",
                appBundleID: app
            )
        )
        #expect(AppRulesSection.card(holding: app, in: guessed) == nil)
        guessed.core.eventLoop.detectedFloating[id] = .floats(.fixedSize)
        #expect(AppRulesSection.card(holding: app, in: guessed) == card)
        guessed.core.eventLoop.detectedFloating[id] = .floats(.panel)
        #expect(AppRulesSection.card(holding: app, in: guessed) == nil)
    }
}
