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

    /// A model whose stored root is Simple, and its defaults.
    private func onSimple() -> (UserDefaults, SettingsModel) {
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        return (defaults, makeTestModel(defaults: defaults))
    }

    @Test("an absent or unknown choice opens the first-open root")
    func defaultIsFirstOpen() {
        let defaults = makeScratchDefaults().defaults
        let first = SettingsRootPreference.firstOpen
        #expect(SettingsRootPreference.read(from: defaults) == first)
        #expect(makeTestModel(defaults: defaults).settingsRoot == first)
        defaults.set("bogus", forKey: SettingsRootPreference.key)
        #expect(SettingsRootPreference.read(from: defaults) == first)
    }

    /// Advanced until Simple has its sections; PR 2 of #2737
    /// flips it to the ruled `.simple` and this pin with it.
    @Test("the first-open root is Advanced until Simple is filled")
    func firstOpenIsPinned() {
        #expect(SettingsRootPreference.firstOpen == .advanced)
    }

    /// The retired key's values meant the old modes, so none of
    /// them moves the first-open root.
    @Test("the retired settingsMode key is never read")
    func retiredKeyIgnored() {
        let first = SettingsRootPreference.firstOpen
        for old in ["simple", "powerUser", "advanced"] {
            let defaults = makeScratchDefaults().defaults
            defaults.set(old, forKey: "settingsMode")
            #expect(SettingsRootPreference.read(from: defaults) == first)
            #expect(makeTestModel(defaults: defaults).settingsRoot == first)
        }
    }

    @Test("the switch's pick survives a new model")
    func choicePersists() {
        let defaults = makeScratchDefaults().defaults
        let model = makeTestModel(defaults: defaults)
        model.pickRoot(.simple)
        #expect(model.settingsRoot == .simple)
        #expect(makeTestModel(defaults: defaults).settingsRoot == .simple)
        model.pickRoot(.advanced)
        #expect(makeTestModel(defaults: defaults).settingsRoot == .advanced)
    }

    @Test("a page is always Advanced's, and shows it without storing")
    func pageFlipsRoot() {
        let (defaults, model) = onSimple()
        #expect(model.showsSimple)
        model.destination = .spaces
        #expect(model.settingsRoot == .advanced)
        #expect(!model.showsSimple)
        // Back from the page lands on Advanced's Home.
        model.destination = nil
        #expect(!model.showsSimple)
        #expect(SettingsRootPreference.read(from: defaults) == .simple)
        // A fresh open shows the stored root again.
        model.prepareToShow(windowShown: false)
        #expect(model.showsSimple)
    }

    @Test("a landing and a named door are not the user's pick")
    func landingIsNotAPick() {
        let (defaults, model) = onSimple()
        // A link waits for its page: no Advanced Home in between.
        model.openAdvanced(SettingsAnchor(destination: .looks))
        #expect(model.settingsRoot == .simple)
        #expect(model.nav.pendingReveal?.destination == .looks)
        model.destination = .looks
        #expect(model.settingsRoot == .advanced)
        // The bare door shows Advanced's Home.
        model.destination = nil
        model.pickRoot(.simple)
        model.openAdvanced()
        #expect(!model.showsSimple)
        model.prepareToShow(windowShown: false)
        #expect(SettingsRootPreference.read(from: defaults) == .simple)
    }

    /// A model on Simple with a stored profile "p" to target.
    private func withStoredProfile() throws -> SettingsModel {
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        let defaults = makeScratchDefaults().defaults
        SettingsRootPreference.write(.simple, to: defaults)
        let model = makeTestModel(core: core, defaults: defaults)
        _ = try core.profiles.write(
            Profile(
                name: "p",
                monitorSets: [MonitorSet(monitors: ["Away:100x100"])],
                spaces: [SpaceID("1")],
                spaceModes: [SpaceID("1"): .bsp],
                settings: TilingSettings()
            )
        )
        model.reload()
        return model
    }

    @Test("Simple edits the loaded profile, whichever way it opens")
    func simpleLeavesAStoredTarget() throws {
        let model = try withStoredProfile()
        model.destination = .spaces
        model.selectEditTarget("p")
        #expect(model.editingStoredProfile)
        model.pickRoot(.simple)
        #expect(!model.editingStoredProfile)
        #expect(model.showsSimple)
        // A page's target does not survive a fresh open on Simple.
        model.destination = .spaces
        model.selectEditTarget("p")
        model.prepareToShow(windowShown: false)
        #expect(model.showsSimple)
        #expect(!model.editingStoredProfile)
    }

    /// Unsaved edits to the stored profile ask first; nothing
    /// moves until the user confirms.
    @Test("a dirty stored target asks before Simple")
    func dirtyStoredTargetAsks() throws {
        let model = try withStoredProfile()
        model.destination = .spaces
        model.selectEditTarget("p")
        model.config.settings.mouse.hoverFocusDelayMS = 1234
        #expect(model.isDirty)
        model.pickRoot(.simple)
        #expect(model.pendingDiscard != nil)
        #expect(model.settingsRoot == .advanced)
        #expect(model.editingStoredProfile)
        #expect(
            SettingsRootPreference.read(from: model.preferences)
                == .simple
        )
        model.pickRoot(.advanced)
        model.pickRoot(.simple)
        #expect(
            SettingsRootPreference.read(from: model.preferences)
                == .advanced
        )
        let pending = try #require(model.pendingDiscard)
        model.confirmPendingDiscard(pending)
        #expect(!model.editingStoredProfile)
        #expect(model.showsSimple)
        #expect(
            SettingsRootPreference.read(from: model.preferences)
                == .simple
        )
    }

    @Test("picking Advanced on screen still stores it")
    func pickOnScreenStores() {
        let (defaults, model) = onSimple()
        model.destination = .spaces
        model.pickRoot(.advanced)
        #expect(SettingsRootPreference.read(from: defaults) == .advanced)
    }

    @Test("picking Simple closes an open page")
    func simpleClosesPage() {
        let model = makeTestModel()
        model.destination = .spaces
        model.pickRoot(.simple)
        #expect(model.destination == nil)
        #expect(model.showsSimple)
    }

    @Test("the Lua editor is never Simple")
    func luaEditorIsNotSimple() {
        let (_, model) = onSimple()
        #expect(model.showsSimple)
        model.showLuaEditor = true
        #expect(!model.showsSimple)
    }

    /// Ruling 15: the tour lands on its page only while the
    /// stored root is Advanced.
    @Test("the tour's landing follows the stored root")
    func tourFollowsStoredRoot() {
        let (_, model) = onSimple()
        model.landFromTour(.macChecklist)
        #expect(model.nav.pendingReveal == nil)
        // A page shows Advanced; the stored root still decides.
        model.destination = .spaces
        model.destination = nil
        model.landFromTour(.macChecklist)
        #expect(model.nav.pendingReveal == nil)
        model.pickRoot(.advanced)
        model.landFromTour(.macChecklist)
        #expect(model.nav.pendingReveal?.destination == .macChecklist)
    }

    @Test("the hidden counts read the draft")
    func hiddenCountsFromDraft() {
        let model = makeTestModel()
        #expect(model.simpleHiddenCounts.isEmpty)
        model.config.appRules = ["mail": SpaceID("1")]
        model.config.floatRules = ["calculator"]
        // The Lua row sits off the default layer, beside a row of
        // another kind, so the count reads every layer and the
        // kind filter.
        model.config.layers = [
            KeyLayer(name: KeyLayer.defaultName),
            KeyLayer(
                name: "Gaming",
                bindings: [
                    KeyBinding(
                        combo: "ctrl+alt+r",
                        lua: "kiwidesk.reload()",
                        kind: .custom
                    ),
                    KeyBinding(
                        combo: "ctrl+alt+g",
                        lua: "kiwidesk.launch(\"Safari\")",
                        kind: .application
                    ),
                ]
            ),
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
