import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The lens page's draft before a Save (#2103 rulings 38, 39): a
/// lens is named as every lens is, a pick of a lens's own reach is
/// no edit, and the save pill narrates every lens edit — a new
/// lens's reach and an edit with no profile loaded included.
@Suite("Lens page draft (#2103)", .serialized)
@MainActor
struct LensPageDraftTests {
    private let writing = KeybindingCatalog.toggleLens("Writing").lua

    /// gui.json binds Writing to W; Home leaves Writing out; Work is
    /// loaded unless `loaded` is false.
    private func makeModel(loaded: Bool = true) throws -> SettingsModel {
        let core = makeTestCore()
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(combo: "w", lua: writing, kind: .navigation)
                ]
            )
        ]
        try core.guiConfigStore.save(config)
        core.setAppWide(persisting: true) {
            $0.visionLenses = [VisionLens(name: "Writing")]
        }
        if loaded {
            try core.profiles.save(profile("Work"))
        } else {
            try core.profiles.write(profile("Work"))
        }
        var home = profile("Home")
        home.lensReach = ["writing": false]
        try core.profiles.write(home)
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func profile(_ name: String) -> Profile {
        Profile(
            name: name,
            monitorSets: [MonitorSet(monitors: [])],
            spaces: [SpaceID("1")],
            spaceModes: [:],
            settings: TilingSettings()
        )
    }

    private func luas(_ model: SettingsModel) -> [String] {
        model.config.layers.flatMap(\.bindings).map(\.lua)
    }

    @Test("a lens is named ignoring case; an unknown one changes nothing")
    func namesMatchAsLensesDo() throws {
        let model = try makeModel()
        #expect(model.renameLens("WRITING", to: "Draft") == nil)
        #expect(model.draftLenses.map(\.name) == ["Draft"])
        let before = model.config.layers
        model.deleteLens("Reading")
        model.renameLens("Reading", to: "Other")
        #expect(model.config.layers == before)
        model.deleteLens("draft")
        #expect(model.draftLenses.isEmpty)
        #expect(!luas(model).contains { $0.contains("Draft") })
    }

    @Test("picking a lens's stored reach again is no edit")
    func storedReachIsNoEdit() throws {
        let model = try makeModel()
        model.setLensReach("Writing", ["Work", "Home"])
        #expect(model.reachEdits.lenses != nil)
        model.setLensReach("Writing", ["Work"])
        #expect(model.reachEdits.lenses == nil)
    }

    @Test("a new lens left out of a profile says so")
    func newLensReachIsNarrated() throws {
        LocalizationManager.shared.select("en")
        let model = try makeModel()
        model.addLens(named: "Reading")
        model.setLensReach("Reading", ["Work"])
        let notes = model.lensDiffRows().compactMap(\.changeNote)
        #expect(notes.contains("added"))
        #expect(notes.contains("left out of Home"))
    }

    @Test("with no profile loaded a lens edit still dirties the draft")
    func noPageStillDirties() throws {
        let model = try makeModel(loaded: false)
        #expect(model.reachProfile == nil)
        model.updateLens("Writing") { $0.keepFocus = false }
        #expect(model.reachDiffRows().count == 1)
        #expect(model.isDirty)
    }
}
