import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A stored-profile Save files the draft's Desktop bindings into
/// `gui.json` (#1392).
///
/// The rows are live under every edit target because bindings
/// are a global table — but that target's Save wrote only the
/// profile file, so un-greying the rows alone would have dropped
/// an edit there on Save with every gate test green. This suite
/// holds the write the ruling depends on, and its shape: the
/// sidecar's OWN map, never the draft's overlay, so the stored
/// profile's Spaces do not materialize into the global file.
@MainActor
@Suite("Stored-profile Save files Desktop bindings (#1392)")
struct StoredProfileBindingSaveTests {
    /// A GUI-managed core with one stored profile that is NOT
    /// the active one (`write`, never `save`), and a model
    /// editing it. The profile declares a Space the sidecar
    /// does not, so an overlay leaking into `gui.json` is
    /// visible.
    private func makeModel() -> SettingsModel {
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        let profile = Profile(
            name: "Away",
            monitorSets: [MonitorSet(monitors: ["Away:100x100"])],
            spaces: [SpaceID("work")],
            spaceModes: [SpaceID("work"): .bsp],
            settings: TilingSettings()
        )
        try? core.profiles.write(profile)
        let model = makeTestModel(core: core)
        model.reload()
        model.selectEditTarget("Away")
        return model
    }

    @Test("an edited binding lands in the sidecar's own map")
    func editedBindingLands() throws {
        let model = makeModel()
        #expect(model.editingStoredProfile)
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Away",
            desktop: 2
        )
        #expect(model.isDirty)

        model.saveEditedProfile()

        let sidecar = try #require(model.core.guiConfigStore.load())
        #expect(sidecar.profileBindings[.number(2)]?.profile == "Away")
        // The stored profile's own Space stays out of the global
        // file: the door writes the store's value, not the draft.
        #expect(!sidecar.spaces.contains(SpaceID("work")))
        // The runtime map followed the write, so the binding
        // fires at the next switch without a restart.
        #expect(
            model.core.desktopBindings[.number(2)]?.profile == "Away"
        )
        // The draft re-seeded clean from the file it just wrote.
        #expect(!model.isDirty)
        #expect(
            model.config.profileBindings[.number(2)]?.profile
                == "Away"
        )
    }

    /// A save that touched no binding leaves the sidecar's bytes
    /// alone — the door is taken on a DIFF, never per save, so a
    /// tiling-only edit to a stored profile does not rewrite the
    /// global file (and reload the config) for nothing.
    @Test("an untouched table writes nothing")
    func untouchedTableWritesNothing() throws {
        let model = makeModel()
        let url = model.core.guiConfigStore.url
        let before = try Data(contentsOf: url)
        model.config.settings.resizeStep += 1
        #expect(model.isDirty)

        model.saveEditedProfile()

        #expect(try Data(contentsOf: url) == before)
    }
}
