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

    @Test("another app's guessed float lands nothing for this app")
    func guessIsPerApp() {
        let model = model()
        let own = WindowID(4_202)
        let other = WindowID(4_203)
        model.core.state.windows.upsert(
            ManagedWindow(
                id: own,
                pid: 4_202,
                appName: "Steam",
                appBundleID: app
            )
        )
        model.core.state.windows.upsert(
            ManagedWindow(
                id: other,
                pid: 4_203,
                appName: "NoMachine",
                appBundleID: "com.nomachine.nxplayer"
            )
        )
        model.core.eventLoop.detectedFloating[own] = .floats(.panel)
        model.core.eventLoop.detectedFloating[other] = .floats(.fixedSize)
        #expect(model.core.floatsOnGuess(app: "com.nomachine.nxplayer"))
        #expect(AppRulesSection.card(holding: app, in: model) == nil)
    }
}

/// The Tile row's ⚠ note (#2173): only a Float rule for the whole
/// app leaves a Tile rule nothing to tile.
@Suite("Automatic floating inert Tile rule (#2173)")
@MainActor
struct AutoFloatInertRowTests {
    private let app = "com.valvesoftware.steam"

    private func floatsEvery(_ rules: [String]) -> Bool {
        var config = GuiConfig()
        config.floatRules = rules
        return AppRuleTileRow.floatsEveryWindow(app: app, config: config)
    }

    @Test("a whole-app Float rule, in any case, makes the rule inert")
    func wholeAppRule() {
        #expect(floatsEvery(["com.ValveSoftware.Steam"]))
    }

    @Test("a title rule or another app's rule leaves it live")
    func otherRules() {
        #expect(!floatsEvery([]))
        #expect(!floatsEvery(["com.valvesoftware.steam:Friends"]))
        #expect(!floatsEvery(["com.nomachine.nxplayer"]))
    }
}
