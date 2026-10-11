import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// `reserve` has no Settings row (#1524, Lua/CLI only), so a
/// Settings Save must carry a value it never shows: a draft that
/// rebuilt the bar styles from its rows would quietly re-reserve
/// a strip the user's `init.lua` freed.
@Suite("Bar reserve survives a Settings Save (#1524)", .serialized)
@MainActor
struct BarReserveSaveTests {
    private func model() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-reserve-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for display in core.state.workspaces.allDisplays {
            core.state.workspaces.removeDisplay(display.id)
        }
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: CGRect(x: 0, y: 0, width: 100, height: 100)
            )
        )
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                spaceModes: [:],
                settings: TilingSettings()
            )
        )
        #expect(
            core.execute("load_profile", args: [.string("Work")])
                .isSuccess
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    @Test("reserve false round-trips through the draft's Save")
    func saveKeepsReserve() throws {
        let model = try model()
        model.config.settings.spaceBarStyle.reserve = false
        model.config.settings.appBarStyle.reserve = false
        // A row edit beside it, so the Save has something to land.
        model.config.settings.spaceBarStyle.glyphSpan = 7
        // `settings` rides the profile file, not gui.json's keys,
        // so the sidecar is read in memory and the file below.
        let sidecar = model.sidecarConfig
        #expect(!sidecar.settings.spaceBarStyle.reserve)
        #expect(!sidecar.settings.appBarStyle.reserve)
        model.updateActiveProfile()
        let core = model.core
        #expect(!core.tiler.settings.spaceBarStyle.reserve)
        #expect(!core.tiler.settings.appBarStyle.reserve)
        let work = try core.profiles.read(name: "Work")
        #expect(!work.settings.spaceBarStyle.reserve)
        #expect(!work.settings.appBarStyle.reserve)
        model.reload()
        #expect(!model.config.settings.spaceBarStyle.reserve)
    }
}
