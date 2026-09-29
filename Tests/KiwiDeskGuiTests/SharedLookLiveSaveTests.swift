import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The loaded profile's Save with a look edit AND a checklist tick
/// (#1752): the edit reaches the shared look, and the profile the
/// tick unticked keeps the look from before the Save — the order
/// `SharedLookSeamTests` ▸ `checklistFirst` pins by spelling, held
/// here by behaviour.
@Suite("Shared look live Save (#1752)", .serialized)
@MainActor
struct SharedLookLiveSaveTests {
    private let odd = "#0A0B0C"

    private func model() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-livesave-\(UUID().uuidString)")
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
        for name in ["Work", "Twin"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["A:100x100"])],
                    spaceModes: [:],
                    settings: TilingSettings(),
                    look: .own
                )
            )
        }
        core.prepareSharedLook()
        #expect(
            core.execute("load_profile", args: [.string("Work")])
                .isSuccess
        )
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    @Test("a look edit and an untick land together")
    func editAndUntickLand() throws {
        let model = try model()
        #expect(model.lookFollows == ["Work": true, "Twin": true])
        model.config.settings.kiwishelf.fillColor = odd
        model.setLookFollows("Twin", false)
        model.updateActiveProfile()
        let core = model.core
        #expect(core.sharedLook?.colors["kiwishelf.fill_color"] == odd)
        #expect(core.tiler.settings.kiwishelf.fillColor == odd)
        let twin = try core.profiles.read(name: "Twin")
        #expect(twin.look == .own)
        #expect(twin.settings.kiwishelf.fillColor != odd)
    }
}
