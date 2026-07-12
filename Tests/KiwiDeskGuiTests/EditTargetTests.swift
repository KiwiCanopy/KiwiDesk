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
    let core = KiwiCore(
        configDirectory: FileManager.default
            .temporaryDirectory
            .appendingPathComponent(
                "kiwi-target-\(UUID().uuidString)"
            )
    )
    // GUI-managed config: the sidecar exists and init.lua
    // holds no foreign code (it doesn't exist at all).
    try? core.guiConfigStore.save(GuiConfig())
    return SettingsModel(core: core)
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
        // global files.
        #expect(model.savedSidecar == nil)
        // The profile's monitors aren't attached.
        #expect(!model.placementEditable)
        // Override-mode baselines for the Shortcuts and App
        // Rules tabs (#55/#109).
        #expect(model.profileEditingBaseModes != nil)
        #expect(model.profileEditingBaseAppRules != nil)
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
        #expect(model.profileEditingBaseModes == nil)
        #expect(model.profileEditingBaseAppRules == nil)
        // GUI-managed: the sidecar baseline is back.
        #expect(model.savedSidecar != nil)
        #expect(!model.isDirty)
    }

    @Test("selecting the active profile normalizes to live")
    func activeProfileIsLive() {
        let model = makeModel()
        // `save` adopts: "active" becomes the current profile.
        try? model.core.profiles.save(
            Profile(
                name: "active",
                monitorSets: [MonitorSet(monitors: [])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        model.reload()
        #expect(model.activeProfile == "active")

        model.selectEditTarget("active")

        #expect(model.target == .live)
        #expect(model.savedSidecar != nil)
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
        #expect(model.profileEditingBaseModes == nil)
        #expect(model.profileEditingBaseAppRules == nil)
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
}
