import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Which app each App Rules list draws (#1608).
///
/// The two lists read the two stores, and nothing else: a Space
/// row drawn for a float-only app — or the reverse — is the
/// one-row form back, where a title pattern read as scoping a
/// Space it never touched (owner, on device, 2026-09-23).
@Suite("App Rules lists (#1608)")
@MainActor
struct AppRuleListsTests {
    private func section(
        pins: [String: String] = [:],
        floats: [String] = []
    ) -> AppRulesSection {
        let model = makeTestModel(core: makeTestCore())
        model.config.spaces = [SpaceID("work"), SpaceID("web")]
        model.config.appRules = pins.mapValues { SpaceID($0) }
        model.config.floatRules = floats
        return AppRulesSection(model: model)
    }

    @Test("a float rule draws no Space row, a pin no Float row")
    func eachListReadsItsOwnStore() {
        let view = section(
            pins: ["com.apple.finder": "work"],
            floats: ["com.apple.calculator", "app.zen:Pull requests"]
        )
        #expect(view.spaceApps == ["com.apple.finder"])
        #expect(
            Set(view.floatApps)
                == ["com.apple.calculator", "app.zen"]
        )
    }

    /// An app may sit in both lists, each row saying one thing.
    @Test("an app with both rules is listed in both")
    func bothRulesListTwice() {
        let view = section(
            pins: ["app.zen": "work"],
            floats: ["app.zen:Pull requests"]
        )
        #expect(view.spaceApps == ["app.zen"])
        #expect(view.floatApps == ["app.zen"])
    }

    /// One row per app however many patterns it carries.
    @Test("several patterns are one Float row")
    func patternsCollapseToTheApp() {
        let view = section(floats: ["app.zen:A", "app.zen:B"])
        #expect(view.floatApps == ["app.zen"])
    }

    @Test("the empty note reads both lists")
    func emptyMeansBothEmpty() {
        #expect(section().hasNoRules)
        #expect(!section(pins: ["a.b": "work"]).hasNoRules)
        #expect(!section(floats: ["a.b"]).hasNoRules)
    }
}
