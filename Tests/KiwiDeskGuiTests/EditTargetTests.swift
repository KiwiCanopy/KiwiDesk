import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

// #64 acceptance: the dashboard's live ⇄ stored-profile mode
// transitions are a single state machine — one reload path that
// always assigns every mode-dependent field.

@MainActor
private func makeModel() -> SettingsModel {
    // makeTestCore's default registrar is already the no-op
    // (#565) — this suite asserts nothing about registration.
    let core = makeTestCore()
    // GUI-managed config: the sidecar exists and init.lua
    // holds no foreign code (it doesn't exist at all).
    try? core.guiConfigStore.save(GuiConfig())
    return makeTestModel(core: core)
}

/// A stored (non-adopted) profile covering one 100×100 display
/// named `monitor` (fingerprint `<monitor>:100x100`).
@MainActor
private func storeProfile(
    _ model: SettingsModel,
    named name: String,
    monitor: String = "Away"
) {
    let profile = Profile(
        name: name,
        monitorSets: [
            MonitorSet(monitors: ["\(monitor):100x100"])
        ],
        spaces: [SpaceID("1")],
        spaceModes: [SpaceID("1"): .bsp],
        settings: TilingSettings()
    )
    // `write`, not `save` — saving adopts (#18) and these
    // tests need a profile that is NOT the active one.
    try? model.core.profiles.write(profile)
    model.reload()
}

@Suite("EditTarget transitions (#64)", .serialized)
@MainActor
struct EditTargetTests {
    @Test("entering stored mode resets every mode field")
    func storedModeResets() {
        let model = makeModel()
        storeProfile(model, named: "p")
        model.showLuaEditor = true
        model.config.floatRules.append("Calculator")
        #expect(model.isDirty)

        model.selectEditTarget("p")

        #expect(model.target == .storedProfile("p"))
        #expect(model.editingStoredProfile)
        // Raw Lua editing is mutually exclusive with stored
        // editing — both entry flags must clear.
        #expect(!model.showLuaEditor)
        #expect(!model.forcedLuaEditor)
        #expect(!model.hasCustomLua)
        // No sidecar baseline: stored edits never write the
        // global files — bar the Desktop bindings, which take
        // their own door (#1392, `StoredProfileBindingSaveTests`).
        #expect(model.savedSidecar == nil)
        // The profile's monitors aren't attached.
        #expect(!model.placementEditable)
        // Override-mode baseline for the Shortcuts tab (#55).
        #expect(model.profileEditingBaseLayers != nil)
        // Pending edits are discarded on switch.
        #expect(!model.isDirty)
    }

    @Test("returning to live restores every mode field")
    func liveModeRestores() {
        let model = makeModel()
        storeProfile(model, named: "p")
        model.selectEditTarget("p")

        model.selectEditTarget(nil)

        #expect(model.target == .live)
        #expect(!model.editingStoredProfile)
        #expect(model.placementEditable)
        #expect(model.profileEditingBaseLayers == nil)
        // GUI-managed: the sidecar baseline is back.
        #expect(model.savedSidecar != nil)
        #expect(!model.isDirty)
    }

    @Test("the loaded profile is the live target, its rules resolved")
    func loadedProfileIsLive() throws {
        let model = makeModel()
        var global = try #require(model.core.guiConfigStore.load())
        global.appRules = ["base.app": SpaceID("1")]
        try model.core.guiConfigStore.save(global)
        // `save` adopts: "active" becomes the current profile.
        try model.core.profiles.save(
            Profile(
                name: "active",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings(),
                appRules: AppRuleOverride(rules: ["own.app": SpaceID("2")])
            )
        )
        model.reload()
        #expect(model.activeProfile == "active")

        model.selectEditTarget("active")

        // #1393: listed once — the loaded profile IS the live
        // target, and its page shows the rules it resolves.
        #expect(model.target == .live)
        #expect(!model.editingStoredProfile)
        #expect(model.config.appRules["own.app"] == SpaceID("2"))
        #expect(model.config.appRules["base.app"] == SpaceID("1"))
        // gui.json takes the shared rules alone.
        #expect(model.sidecarConfig.appRules == ["base.app": SpaceID("1")])
    }

    @Test("a vanished profile falls back to live editing")
    func vanishedProfileFallsBack() {
        let model = makeModel()
        storeProfile(model, named: "p")
        model.selectEditTarget("p")
        try? model.core.profiles.delete(name: "p")

        model.reload()

        #expect(model.target == .live)
        #expect(model.placementEditable)
        #expect(model.profileEditingBaseLayers == nil)
    }

    @Test("forced Lua clears in stored mode, returns on live")
    func forcedLuaRoundTrip() throws {
        let model = makeModel()
        // Managed vocabulary outside the managed block forces
        // the raw editor (#14/#55): binds are GUI-owned.
        try "KiwiDesk.bind(\"cmd+1\", function() end)".write(
            to: model.core.configURL,
            atomically: true,
            encoding: .utf8
        )
        storeProfile(model, named: "p")
        #expect(model.forcedLuaEditor)

        model.selectEditTarget("p")
        #expect(!model.forcedLuaEditor)
        #expect(model.luaSource.isEmpty)

        model.selectEditTarget(nil)
        #expect(model.forcedLuaEditor)
        #expect(!model.luaSource.isEmpty)
    }

    @Test("a reload clears the conflict banner")
    func reloadClearsKeybindingWarning() {
        let model = makeModel()
        storeProfile(model, named: "p")
        model.keybindingWarning = "conflict!"

        model.selectEditTarget("p")

        // The banner described the previous target's edits —
        // it must not survive the switch (#68 review).
        #expect(model.keybindingWarning == nil)
    }

    @Test("placement is editable when the monitors match")
    func placementEditableOnMatch() {
        let model = makeModel()
        model.core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "Here",
                frame: CGRect(
                    x: 0,
                    y: 0,
                    width: 100,
                    height: 100
                )
            )
        )
        storeProfile(model, named: "p", monitor: "Here")

        model.selectEditTarget("p")

        #expect(model.placementEditable)
    }

    @Test("Live float edit writes the global sidecar")
    func liveFloatEditWritesGlobal() throws {
        let model = makeModel()
        model.config.floatRules = ["global.float"]

        model.saveAsNewProfile(named: "Live")

        let global = try #require(
            model.core.guiConfigStore.load()
        )
        #expect(global.floatRules == ["global.float"])
        let profile = try model.core.profiles.read(name: "Live")
        #expect(profile.floatRules == nil)
    }

    @Test("A stored float edit removed here writes the profile diff")
    func storedFloatEditWritesProfile() throws {
        let model = makeModel()
        var global = try #require(
            model.core.guiConfigStore.load()
        )
        global.floatRules = ["base.float"]
        try model.core.guiConfigStore.save(global)
        storeProfile(model, named: "p")
        model.selectEditTarget("p")
        // The trash's "Remove from p" (#1393); the new rule starts
        // at "p only" on a profile that isn't loaded.
        model.recordRemoval(.float, "base.float", .here)
        model.config.floatRules = ["profile.float"]

        model.saveEditedProfile()

        let savedGlobal = try #require(
            model.core.guiConfigStore.load()
        )
        #expect(savedGlobal.floatRules == ["base.float"])
        let profile = try model.core.profiles.read(name: "p")
        #expect(
            profile.floatRules
                == RuleListOverride(rules: [
                    "base.float": nil,
                    "profile.float": true,
                ])
        )
    }
}
