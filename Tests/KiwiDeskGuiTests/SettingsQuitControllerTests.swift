import AppKit
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class QuitControllerRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

/// The Settings window controller's half of #2049, driven without
/// opening its window: the close question, the quit verdict and
/// its one-shot pass, the SIGTERM drop, and the one primary Save
/// the question runs. Locale pinned per body (#740).
@Suite("Settings close and quit verdicts (#2049)", .serialized)
@MainActor
struct SettingsQuitControllerTests {
    private func makeController() throws -> SettingsWindowController {
        LocalizationManager.shared.select("en")
        let core = makeTestCore(
            hotkeyRegistrar: QuitControllerRegistrar()
        )
        try core.saveGuiConfig(GuiConfig())
        return SettingsWindowController(model: makeTestModel(core: core))
    }

    /// A never-shown window to hand the delegate.
    private func window() -> NSWindow {
        let window = NSWindow(
            contentRect: .zero,
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: true
        )
        window.isReleasedWhenClosed = false
        return window
    }

    private func dirty(_ model: SettingsModel) {
        model.config.settings.gapsGlobal.inner.horizontal += 7
        #expect(model.isDirty)
    }

    @Test("a close with unsaved edits is held behind the question")
    func dirtyCloseAsks() throws {
        let controller = try makeController()
        #expect(controller.windowShouldClose(window()))
        #expect(controller.model.pendingDiscard == nil)
        dirty(controller.model)
        #expect(!controller.windowShouldClose(window()))
        #expect(controller.model.pendingDiscard?.kind == .leave(.close))
    }

    @Test("a quit asks only while Settings is open and unsaved")
    func quitVerdict() throws {
        #expect(SettingsWindowController.quitAsks(shown: true, dirty: true))
        #expect(!SettingsWindowController.quitAsks(shown: true, dirty: false))
        #expect(!SettingsWindowController.quitAsks(shown: false, dirty: true))
        let controller = try makeController()
        dirty(controller.model)
        // Never shown: a hidden Settings never asks.
        #expect(!controller.quitAsksAboutDraft)
    }

    @Test("an answered quit passes once")
    func answerPassesOnce() throws {
        let controller = try makeController()
        #expect(!controller.takeQuitAnswer())
        controller.model.quitAnswered = true
        #expect(controller.takeQuitAnswer())
        #expect(!controller.takeQuitAnswer())
    }

    @Test("a SIGTERM's quit drops the draft through the controller")
    func dropReachesTheModel() throws {
        let controller = try makeController()
        dirty(controller.model)
        controller.dropDraftForQuit()
        #expect(!controller.model.isDirty)
    }
}

/// The one primary Save the question runs, on a loaded profile
/// (#2049): its gate, and a direct Save that fails.
@Suite("Primary Save verdicts (#2049)", .serialized)
@MainActor
struct PrimarySaveVerdictTests {
    /// Work loaded, Home stored, a clean live draft.
    private func makeModel() throws -> SettingsModel {
        LocalizationManager.shared.select("en")
        let core = makeTestCore()
        try core.guiConfigStore.save(GuiConfig())
        try core.profiles.save(profile("Work"))
        try core.profiles.write(profile("Home"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1"), SpaceID("2")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    @Test("Save is greyed on a clean loaded profile")
    func cleanIsGreyed() throws {
        let model = try makeModel()
        #expect(model.primarySaveAction == .updateActiveProfile)
        #expect(model.updateEnabled)
        #expect(model.profileSaveBlockedReason == nil)
        #expect(!model.isDirty && !model.profileDirty)
        #expect(!model.primarySaveEnabled)
        model.config.appRules["notes"] = SpaceID("2")
        #expect(model.primarySaveEnabled)
    }

    @Test("a direct Save that fails cancels and keeps the draft")
    func failedDirectSaveCancels() throws {
        let model = try makeModel()
        model.config.appRules["notes"] = SpaceID("2")
        // A profile loaded under the dirty draft refuses its Save.
        _ = try model.core.loadProfile(named: "Home")
        model.refreshProfiles()
        #expect(model.primarySaveAction == .updateActiveProfile)
        var proceeded = 0
        var cancelled = 0
        model.leavingDraft(
            .quit,
            proceed: { proceeded += 1 },
            cancel: { cancelled += 1 }
        )
        model.saveAndLeave(try #require(model.pendingDiscard))
        #expect(model.isDirty)
        #expect(cancelled == 1)
        #expect(proceeded == 0)
    }
}
