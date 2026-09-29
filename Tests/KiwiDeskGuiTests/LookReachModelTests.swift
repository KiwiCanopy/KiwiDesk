import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The "Look applies to" checklist's draft half (#1752): a tick is
/// staged, marks the draft dirty with one save-pill row per
/// profile, a tick back drops it, and a Save writes it through
/// Core's one door.
@Suite("Look reach model (#1752)", .serialized)
@MainActor
struct LookReachModelTests {
    private func model() throws -> SettingsModel {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent("kiwi-lookreach-\(UUID().uuidString)")
        )
        try core.guiConfigStore.save(GuiConfig())
        for name in ["Work", "Home"] {
            try core.profiles.save(
                Profile(
                    name: name,
                    monitorSets: [MonitorSet(monitors: ["\(name):1x1"])],
                    spaceModes: [:],
                    settings: TilingSettings()
                )
            )
        }
        let model = makeTestModel(core: core)
        model.resetLookReach()
        model.recomputeDirty()
        return model
    }

    @Test("a tick is staged, dirty, and one row")
    func tickIsStaged() throws {
        let model = try model()
        #expect(model.lookFollows == ["Work": true, "Home": true])
        #expect(!model.isDirty)
        model.setLookFollows("Home", false)
        #expect(model.lookFollows["Home"] == false)
        #expect(model.isDirty)
        #expect(model.lookReachDiffRows().map(\.label) == ["Home"])
    }

    @Test("a tick back to what is stored leaves nothing unsaved")
    func tickBackIsClean() throws {
        let model = try model()
        model.setLookFollows("Home", false)
        model.setLookFollows("Home", true)
        #expect(model.lookReachEdits.isEmpty)
        #expect(!model.isDirty)
    }

    @Test("All profiles ticks every profile")
    func allProfiles() throws {
        let model = try model()
        model.lookReachStored = ["Work": false, "Home": false]
        model.setLookFollowsAll()
        #expect(model.lookFollows == ["Work": true, "Home": true])
    }

    @Test("a Save writes the ticks and clears them")
    func saveWrites() throws {
        let model = try model()
        model.setLookFollows("Home", false)
        #expect(model.saveLookReach())
        #expect(model.lookReachEdits.isEmpty)
        #expect(try model.core.profiles.read(name: "Home").look == .own)
        #expect(model.lookReachStored["Home"] == false)
    }
}
