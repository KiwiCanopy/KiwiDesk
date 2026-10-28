import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The Simple / Advanced roots (#2737): the stored choice, the
/// rule that every page is Advanced's, and the header line naming
/// what Simple hides.
@MainActor
@Suite("Simple root")
struct SimpleRootTests {
    private func pinEnglish() {
        LocalizationManager.shared.select("en")
    }

    @Test("an absent or unknown choice opens Simple")
    func defaultIsSimple() {
        let defaults = makeScratchDefaults().defaults
        #expect(SettingsRootPreference.read(from: defaults) == .simple)
        defaults.set("bogus", forKey: SettingsRootPreference.key)
        #expect(SettingsRootPreference.read(from: defaults) == .simple)
    }

    /// The retired key's values meant the old modes; a user who
    /// had picked Power User still opens Simple.
    @Test("the retired settingsMode key is never read")
    func retiredKeyIgnored() {
        let defaults = makeScratchDefaults().defaults
        defaults.set("powerUser", forKey: "settingsMode")
        defaults.set("advanced", forKey: "settingsMode")
        #expect(SettingsRootPreference.read(from: defaults) == .simple)
        #expect(makeTestModel(defaults: defaults).settingsRoot == .simple)
    }

    @Test("the choice survives a new model")
    func choicePersists() {
        let defaults = makeScratchDefaults().defaults
        let model = makeTestModel(defaults: defaults)
        model.settingsRoot = .advanced
        #expect(makeTestModel(defaults: defaults).settingsRoot == .advanced)
        model.settingsRoot = .simple
        #expect(makeTestModel(defaults: defaults).settingsRoot == .simple)
    }

    @Test("a page is always Advanced's")
    func pageFlipsRoot() {
        let defaults = makeScratchDefaults().defaults
        let model = makeTestModel(defaults: defaults)
        #expect(model.showsSimple)
        model.destination = .spaces
        #expect(model.settingsRoot == .advanced)
        #expect(!model.showsSimple)
        // Back from the page lands on Advanced's Home.
        model.destination = nil
        #expect(!model.showsSimple)
        #expect(makeTestModel(defaults: defaults).settingsRoot == .advanced)
    }

    @Test("openAdvanced leaves Simple, with or without a page")
    func openAdvanced() {
        let model = makeTestModel()
        model.openAdvanced()
        #expect(model.settingsRoot == .advanced)
        #expect(model.destination == nil)
        model.settingsRoot = .simple
        model.openAdvanced(.looks)
        #expect(model.destination == .looks)
        #expect(!model.showsSimple)
    }

    @Test("the hidden counts read the draft")
    func hiddenCountsFromDraft() {
        let model = makeTestModel()
        #expect(model.simpleHiddenCounts.isEmpty)
        model.config.appRules = ["mail": SpaceID("1")]
        model.config.floatRules = ["calculator"]
        model.config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+r",
                        lua: "kiwidesk.reload()",
                        kind: .custom
                    )
                ]
            ),
            KeyLayer(name: "Gaming"),
        ]
        #expect(
            model.simpleHiddenCounts
                == SimpleHiddenCounts(appRules: 2, layers: 1, luaBindings: 1)
        )
    }

    @Test("the subtitle drops each clause at zero")
    func subtitleClauses() {
        pinEnglish()
        #expect(
            SimpleHeaderSubtitle.line(
                screenCount: 0,
                hidden: SimpleHiddenCounts()
            ) == nil
        )
        #expect(
            SimpleHeaderSubtitle.line(
                screenCount: 1,
                hidden: SimpleHiddenCounts()
            ) == "1 screen"
        )
        let slot = CrossReferenceRow.linkSlot
        #expect(
            SimpleHeaderSubtitle.line(
                screenCount: 2,
                hidden: SimpleHiddenCounts(
                    appRules: 3,
                    layers: 2,
                    luaBindings: 1
                )
            )
                == "2 screens · 3 App Rules · 2 shortcut layers"
                + " · 1 Lua binding, kept in \(slot)"
        )
        #expect(
            SimpleHeaderSubtitle.line(
                screenCount: 0,
                hidden: SimpleHiddenCounts(layers: 1)
            ) == "1 shortcut layer, kept in \(slot)"
        )
    }

    /// The retired key may be named in prose, never read: no Swift
    /// source spells it as a string literal.
    @Test("no source spells the retired key")
    func retiredKeyUnspelled() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources")
        let files = try SourceScan.swiftSources(under: root)
        #expect(!files.isEmpty)
        let readers = try files.filter {
            try String(contentsOf: $0, encoding: .utf8)
                .contains("\"settingsMode\"")
        }
        #expect(readers.isEmpty)
    }
}
