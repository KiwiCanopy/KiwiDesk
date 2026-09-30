import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A bar menu's App Rules… (#1518): Settings opens App Rules
/// scrolled to, and flashing, the card holding that app's rule —
/// the Space list first — as the search lands, moving no focus
/// (#991). An app with no rule lands on the page and nothing is
/// created (#1022).
@Suite("App Rules landing from a bar menu", .serialized)
@MainActor
struct AppRuleLandingTests {
    private let app = "com.apple.safari"

    private func model(
        space: Bool = false,
        float: Bool = false
    ) -> SettingsModel {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        let model = makeTestModel(core: core)
        model.reload()
        if space { model.config.appRules[app] = SpaceID("2") }
        if float { model.config.floatRules.append(app) }
        return model
    }

    /// The row is a surface of App Rules alone: the reveal keeps it
    /// there and nowhere else.
    @Test("the landing opens App Rules on that app's row")
    func landingResolves() throws {
        let anchor = SettingsAnchor(landing: .appRule(app))
        let resolved = try #require(
            anchor.resolved(editingStoredProfile: false)
        )
        #expect(resolved.destination == .appRules)
        #expect(resolved.surface == .appRule(app))
        let stray = SettingsAnchor(
            destination: .bars,
            surface: .appRule(app)
        )
        #expect(
            stray.resolved(editingStoredProfile: false)?.surface == .main
        )
    }

    @Test("the card is the list holding the rule, the Space list first")
    func cardFollowsTheRule() {
        let spaceList = SettingsCatalog.appRules.spaceList
        let floatList = SettingsCatalog.appRules.floatList
        #expect(
            AppRulesSection.card(holding: app, in: model(space: true))
                == spaceList
        )
        #expect(
            AppRulesSection.card(holding: app, in: model(float: true))
                == floatList
        )
        #expect(
            AppRulesSection.card(
                holding: app,
                in: model(space: true, float: true)
            ) == spaceList
        )
        #expect(AppRulesSection.card(holding: app, in: model()) == nil)
    }

    /// Through the one reveal consumer: the page and the card to
    /// scroll to — and for an app with no rule, the page alone,
    /// with the draft untouched.
    @Test("the reveal scrolls to the card holding the rule")
    func revealNamesTheRow() {
        let ruled = model(float: true)
        let landing = SettingsAnchor(landing: .appRule(app))
        SettingsView(model: ruled).apply(landing)
        #expect(ruled.destination == .appRules)
        let floatList = SettingsCatalog.appRules.floatList.id
        #expect(ruled.nav.pendingScroll == floatList)
        let bare = model()
        SettingsView(model: bare).apply(landing)
        #expect(bare.destination == .appRules)
        #expect(bare.nav.pendingScroll == nil)
        #expect(!bare.isDirty)
    }
}
