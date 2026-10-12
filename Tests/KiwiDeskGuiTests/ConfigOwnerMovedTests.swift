import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// An `init.lua` that takes the config over while a structured
/// live page is open (#2183): a clean page re-draws as the Lua
/// editor, and a dirty one refuses its Save rather than writing
/// a `gui.json` the next load ignores.
@Suite("Config owner moved under the page (#2183)", .serialized)
@MainActor
struct ConfigOwnerMovedTests {
    /// gui.json opens Mail in Space 1; Work is loaded.
    private func makeModel() throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1"), SpaceID("2")]
        config.appRules = ["mail": SpaceID("1")]
        try core.guiConfigStore.save(config)
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: [])],
                spaces: [SpaceID("1"), SpaceID("2")],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    /// Managed vocabulary outside the managed block: binds are
    /// GUI-owned, so the visual editor cannot co-own the file.
    private func writeForeignLua(_ model: SettingsModel) throws {
        try "KiwiDesk.bind(\"cmd+1\", function() end)".write(
            to: model.core.configURL,
            atomically: true,
            encoding: .utf8
        )
    }

    @Test("A clean live page re-draws as the Lua editor")
    func cleanPageReloads() throws {
        let model = try makeModel()
        #expect(!model.editingLua)
        try writeForeignLua(model)

        model.refreshProfiles()

        #expect(model.editingLua)
        #expect(!model.ownerMoved)
    }

    @Test("A dirty live draft refuses its Save")
    func dirtyDraftRefuses() throws {
        let model = try makeModel()
        model.config.appRules["mail"] = SpaceID("2")
        try writeForeignLua(model)
        model.refreshProfiles()
        #expect(!model.editingLua)

        model.updateActiveProfile()

        #expect(model.profileWarning == model.staleDraftReason)
        #expect(model.profileWarning != nil)
        #expect(
            model.core.guiConfigStore.load()?.appRules["mail"]
                == SpaceID("1")
        )
    }

    @Test("A clean draft is never refused before its refresh")
    func cleanDraftIsNotRefused() throws {
        let model = try makeModel()
        try writeForeignLua(model)
        #expect(model.ownerMoved)

        #expect(model.staleDraftReason == nil)
    }

    @Test("A paused globals Save refuses too")
    func pausedGlobalsRefuse() throws {
        let model = try makeModel()
        model.config.appRules["mail"] = SpaceID("2")
        try writeForeignLua(model)

        model.saveGlobalsWhilePaused()

        // Only the warning can red: the door's own ownership guard
        // already kept gui.json unwritten before #2183.
        #expect(model.profileWarning == model.staleDraftReason)
        #expect(model.profileWarning != nil)
    }

    @Test("Settings becoming key re-draws a clean page")
    func windowKeyReloads() throws {
        let model = try makeModel()
        let controller = SettingsWindowController(model: model)
        try writeForeignLua(model)

        controller.windowDidBecomeKey(
            Notification(name: NSWindow.didBecomeKeyNotification)
        )

        #expect(model.editingLua)
    }
}
