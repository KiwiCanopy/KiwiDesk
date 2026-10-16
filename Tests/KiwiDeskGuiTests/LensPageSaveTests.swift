import CoreGraphics
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// The lens page's Save (#2103 rulings 29, 38, 39, 40): a rename
/// or delete reaches every stored chord and every profile's
/// `lens_reach` in the one layer pass, the lenses land in
/// `gui.json` from the SETTLED list, and the lens on follows a
/// rename the Save carries.
@Suite("Lens page Save (#2103)", .serialized)
@MainActor
struct LensPageSaveTests {
    private let writing = KeybindingCatalog.toggleLens("Writing").lua
    private let reading = KeybindingCatalog.toggleLens("Reading").lua

    /// gui.json binds Writing to W and Reading to R in the shared
    /// layer; Work is loaded, Home leaves Writing out and binds it
    /// to H in a layer override, Travel is plain.
    private func makeModel(loaded: Bool = true) throws -> SettingsModel {
        let core = makeTestCore()
        core.tiler.visibleBounds = { _ in
            CGRect(x: 0, y: 0, width: 1200, height: 800)
        }
        core.eventLoop.ownKeyWindow = { nil }
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [bind("w", writing), bind("r", reading)]
            )
        ]
        try core.guiConfigStore.save(config)
        core.setAppWide(persisting: true) {
            $0.visionLenses = [lens("Writing"), lens("Reading")]
        }
        if loaded {
            try core.profiles.save(profile("Work"))
        } else {
            try core.profiles.write(profile("Work"))
        }
        var home = profile("Home")
        home.lensReach = ["writing": false]
        home.layers = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [bind("h", writing), bind("r", reading)]
                )
            ]
        )
        try core.profiles.write(home)
        try core.profiles.write(profile("Travel"))
        let model = makeTestModel(core: core)
        model.reload()
        return model
    }

    private func lens(_ name: String) -> VisionLens {
        var lens = VisionLens(name: name)
        lens.apps = ["test.kiwi.notes"]
        return lens
    }

    private func bind(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation)
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

    private func storedNames(_ model: SettingsModel) -> [String] {
        model.core.guiConfigStore.load()?.appWide?.visionLenses
            .map(\.name) ?? []
    }

    private func luas(_ layers: [KeyLayer]?) -> [String] {
        (layers ?? []).flatMap(\.bindings).map(\.lua)
    }

    private func homeLayers(_ model: SettingsModel) throws -> [KeyLayer] {
        let base = model.core.guiConfigStore.load()?.layers ?? []
        return try model.core.profiles.read(name: "Home").layers?
            .resolved(onto: base) ?? base
    }

    @Test("a rename re-keys every stored chord and mark")
    func renameReachesEveryFile() throws {
        let model = try makeModel()
        #expect(model.renameLens("Writing", to: "Draft") == nil)
        model.updateActiveProfile()
        let draft = KeybindingCatalog.toggleLens("Draft").lua
        #expect(storedNames(model) == ["Draft", "Reading"])
        let base = model.core.guiConfigStore.load()?.layers
        #expect(luas(base).contains(draft))
        #expect(!luas(base).contains(writing))
        let home = try homeLayers(model)
        #expect(luas(home).contains(draft) && !luas(home).contains(writing))
        let marks = try model.core.profiles.read(name: "Home").lensReach
        #expect(marks == ["draft": false])
    }

    @Test("a stored page's Save and the paused Save carry the lenses")
    func otherDoorsCarryTheLenses() throws {
        let stored = try makeModel()
        stored.selectEditTarget("Home")
        #expect(stored.target == .storedProfile("Home"))
        stored.renameLens("Writing", to: "Draft")
        stored.saveEditedProfile()
        let draft = KeybindingCatalog.toggleLens("Draft").lua
        #expect(storedNames(stored) == ["Draft", "Reading"])
        #expect(luas(try homeLayers(stored)).contains(draft))
        #expect(
            try stored.core.profiles.read(name: "Home").lensReach
                == ["draft": false]
        )

        let paused = try makeModel()
        paused.deleteLens("Reading")
        paused.saveGlobalsWhilePaused()
        #expect(storedNames(paused) == ["Writing"])
        let base = luas(paused.core.guiConfigStore.load()?.layers)
        #expect(!base.contains(reading))
    }

    @Test("with no profile loaded the crossings still reach every file")
    func builtInLiveCarriesTheCrossings() throws {
        let model = try makeModel(loaded: false)
        #expect(model.reachProfile == nil)
        model.renameLens("Writing", to: "Draft")
        model.setLensReach("Reading", ["Work"])
        model.saveAsNewProfile(named: "New")
        #expect(storedNames(model) == ["Draft", "Reading"])
        let draft = KeybindingCatalog.toggleLens("Draft").lua
        #expect(luas(try homeLayers(model)).contains(draft))
        #expect(
            try model.core.profiles.read(name: "Home").lensReach
                == ["draft": false, "reading": false]
        )
    }

    @Test("a delete frees every stored chord and clears its marks")
    func deleteReachesEveryFile() throws {
        let model = try makeModel()
        model.deleteLens("Writing")
        model.updateActiveProfile()
        #expect(storedNames(model) == ["Reading"])
        let base = luas(model.core.guiConfigStore.load()?.layers)
        #expect(!base.contains(writing))
        #expect(!luas(try homeLayers(model)).contains(writing))
        #expect(try model.core.profiles.read(name: "Home").lensReach == nil)
    }

    @Test("a swap through three renames merges nothing")
    func swapMergesNothing() throws {
        let model = try makeModel()
        model.renameLens("Writing", to: "Tmp")
        model.renameLens("Reading", to: "Writing")
        model.renameLens("Tmp", to: "Reading")
        model.updateActiveProfile()
        let base = model.core.guiConfigStore.load()?.layers ?? []
        let combos = Dictionary(
            uniqueKeysWithValues: base.flatMap(\.bindings).map {
                ($0.combo, $0.lua)
            }
        )
        #expect(combos["w"] == reading)
        #expect(combos["r"] == writing)
        let marks = try model.core.profiles.read(name: "Home").lensReach
        #expect(marks == ["reading": false])
    }

    @Test("an Applies to pick marks every other saved profile")
    func reachPickWritesMarks() throws {
        let model = try makeModel()
        #expect(model.lensReach("Writing") == ["Work", "Travel"])
        model.setLensReach("Reading", ["Work"])
        #expect(model.lensDiffRows().count == 2)
        model.updateActiveProfile()
        let read = { try model.core.profiles.read(name: $0).lensReach }
        #expect(try read("Work") == nil)
        #expect(try read("Travel") == ["reading": false])
        #expect(try read("Home") == ["writing": false, "reading": false])
    }

    @Test("a session define_lens never reaches the file")
    func sessionLensStaysSession() throws {
        let model = try makeModel()
        model.core.execute(
            "kiwivision.define_lens",
            args: [.object(["name": .string("Scratch")])]
        )
        #expect(model.draftLenses.map(\.name) == ["Writing", "Reading"])
        model.renameLens("Reading", to: "Study")
        model.updateActiveProfile()
        #expect(storedNames(model) == ["Writing", "Study"])
    }

    @Test("the lens on follows the rename the Save carries")
    func activeFollowsTheSave() throws {
        let model = try makeModel()
        model.core.execute("kiwivision.toggle", args: [.string("Writing")])
        #expect(model.core.kiwiVisionActive == .lens("Writing"))
        model.renameLens("Writing", to: "Draft")
        model.updateActiveProfile()
        #expect(model.core.kiwiVisionActive == .lens("Draft"))
    }

    @Test("the lens on stays on through a swap the Save carries")
    func swapKeepsTheLensOn() throws {
        let model = try makeModel()
        model.core.execute("kiwivision.toggle", args: [.string("Reading")])
        _ = try model.core.loadProfile(named: "Home")
        model.reload()
        // Home leaves Writing out; Reading is on.
        #expect(model.core.kiwiVisionActive == .lens("Reading"))
        model.renameLens("Writing", to: "Tmp")
        model.renameLens("Reading", to: "Writing")
        model.renameLens("Tmp", to: "Reading")
        model.updateActiveProfile()
        #expect(model.core.kiwiVisionActive == .lens("Writing"))
    }

    @Test("a pick leaving the live profile out turns the lens on off")
    func pickJudgedAfterTheSave() throws {
        let model = try makeModel()
        model.core.execute("kiwivision.toggle", args: [.string("Reading")])
        #expect(model.core.kiwiVisionActive == .lens("Reading"))
        model.setLensReach("Reading", ["Home"])
        model.updateActiveProfile()
        #expect(model.core.kiwiVisionActive == .off)
    }

    @Test("an edit dirties the draft; undoing it cleans it")
    func draftDirtiesAndCleans() throws {
        let model = try makeModel()
        model.renameLens("Writing", to: "Draft")
        #expect(model.isDirty)
        #expect(!model.lensDiffRows().isEmpty)
        model.renameLens("Draft", to: "Writing")
        #expect(model.reachEdits.lenses == nil)
        #expect(!model.isDirty)
    }

    @Test("names are unique ignoring case and at most 40 characters")
    func namesAreRefused() throws {
        let model = try makeModel()
        #expect(model.addLens(named: "  ") == .empty)
        #expect(model.addLens(named: "writing") == .taken("Writing"))
        #expect(
            model.addLens(named: String(repeating: "x", count: 41))
                == .tooLong
        )
        #expect(model.renameLens("Writing", to: "WRITING") == nil)
        #expect(model.draftLenses.first?.name == "WRITING")
    }
}
