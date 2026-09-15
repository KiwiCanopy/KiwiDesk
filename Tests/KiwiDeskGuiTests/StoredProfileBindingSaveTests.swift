import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// A stored-profile Save files the draft's Desktop bindings into
/// `gui.json` (#1392) — that target's Save otherwise writes only
/// the profile file, so a live row there would drop its edit.
/// Held here: the write lands per entry on the STORE's own map,
/// is skipped when no row was touched, and refuses a sidecar
/// that no longer decodes.
@MainActor
@Suite("Stored-profile Save files Desktop bindings (#1392)")
struct StoredProfileBindingSaveTests {
    /// A Space list neither the live engine (boot default `1`)
    /// nor the edited profile (`work`) has, so a write that took
    /// either overlay instead of the store's own value shows in
    /// the file.
    private static var sidecar: GuiConfig {
        var config = GuiConfig()
        config.spaces = [SpaceID("side")]
        config.profileBindings = [
            .number(1): DesktopBinding(profile: "Kept", desktop: 1)
        ]
        return config
    }

    /// A GUI-managed core with one stored profile that is NOT
    /// the active one (`write`, never `save`), and a model
    /// editing it.
    private func makeModel(
        sidecarBytes: Data? = nil
    ) throws -> SettingsModel {
        let core = makeTestCore()
        if let sidecarBytes {
            try FileManager.default.createDirectory(
                at: core.guiConfigStore.url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try sidecarBytes.write(to: core.guiConfigStore.url)
        } else {
            try core.guiConfigStore.save(Self.sidecar)
        }
        let profile = Profile(
            name: "Away",
            monitorSets: [MonitorSet(monitors: ["Away:100x100"])],
            spaces: [SpaceID("work")],
            spaceModes: [SpaceID("work"): .bsp],
            settings: TilingSettings()
        )
        try core.profiles.write(profile)
        let model = makeTestModel(core: core)
        model.reload()
        model.selectEditTarget("Away")
        #expect(model.editingStoredProfile)
        return model
    }

    @Test("an edited binding lands on the sidecar's own map")
    func editedBindingLands() throws {
        let model = try makeModel()
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Away",
            desktop: 2
        )
        #expect(model.isDirty)

        model.saveEditedProfile()

        let sidecar = try #require(model.core.guiConfigStore.load())
        #expect(sidecar.profileBindings[.number(2)]?.profile == "Away")
        // The untouched entry and the store's own non-binding
        // value both survive: neither the draft's table nor the
        // live overlay was written wholesale.
        #expect(sidecar.profileBindings[.number(1)]?.profile == "Kept")
        #expect(sidecar.spaces == [SpaceID("side")])
        // The draft re-seeded clean from the file it just wrote.
        #expect(!model.isDirty)
        #expect(
            model.config.profileBindings[.number(2)]?.profile
                == "Away"
        )
    }

    /// Per ENTRY: a row the store gained under the open draft
    /// survives the Save — the user owns the rows they touched
    /// and nothing else (#1147).
    @Test("a row the store gained meanwhile survives the save")
    func storeRowSurvives() throws {
        let model = try makeModel()
        var moved = try #require(model.core.guiConfigStore.load())
        moved.profileBindings[.number(3)] = DesktopBinding(
            profile: "Late",
            desktop: 3
        )
        try model.core.guiConfigStore.save(moved)
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Away",
            desktop: 2
        )

        model.saveEditedProfile()

        let sidecar = try #require(model.core.guiConfigStore.load())
        #expect(sidecar.profileBindings[.number(3)]?.profile == "Late")
        #expect(sidecar.profileBindings[.number(2)]?.profile == "Away")
    }

    /// With a VM up the write reloads, so the runtime map follows
    /// without a restart; the cold-boot branch above writes the
    /// store alone and `start()` picks it up.
    @Test("with a running VM the runtime map follows the write")
    func runtimeMapFollows() throws {
        let model = try makeModel()
        model.core.loadConfig()
        let generation = model.core.keybindingRuntimeGeneration
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Away",
            desktop: 2
        )

        model.saveEditedProfile()

        #expect(
            model.core.desktopBindings[.number(2)]?.profile == "Away"
        )
        #expect(model.core.keybindingRuntimeGeneration > generation)
    }

    /// Seeded with COMPACT JSON, which the store's pretty-printed
    /// save can never reproduce — so any write, even of an
    /// unchanged table, changes the bytes.
    @Test("an untouched table writes nothing")
    func untouchedTableWritesNothing() throws {
        let compact = try JSONEncoder().encode(Self.sidecar)
        let model = try makeModel(sidecarBytes: compact)
        model.config.settings.resizeStep += 1
        #expect(model.isDirty)

        model.saveEditedProfile()

        #expect(
            try Data(contentsOf: model.core.guiConfigStore.url)
                == compact
        )
    }

    /// The reachable un-seeded state (#354's class): a `set_*`-only
    /// `init.lua` and no sidecar. The model reads both facts the
    /// resolver greys on, the door refuses by name, and Live —
    /// whose Save mints the sidecar — is never greyed.
    @Test("a set_*-only init.lua, no sidecar: stored target greys")
    func unseededConfigGreysStoredOnly() throws {
        let core = makeTestCore()
        try FileManager.default.createDirectory(
            at: core.configURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "KiwiDesk.set_gap(8)\n".write(
            to: core.configURL,
            atomically: true,
            encoding: .utf8
        )
        let model = makeTestModel(core: core)
        model.reload()
        #expect(!model.guiManaged)
        #expect(!model.sidecarExists)
        func reason(editing: Bool) -> ProfilesGates.InertReason? {
            ProfilesGates(
                editingStoredProfile: editing,
                connectedScreens: 1,
                guiManaged: model.guiManaged,
                sidecarExists: model.sidecarExists
            ).inertReason(for: .profiles(.profileBindings))
        }
        #expect(reason(editing: false) == nil)
        #expect(reason(editing: true) == .noSidecar)
        #expect(throws: SidecarError.missing) {
            try core.rewriteSidecarBindings { _ in }
        }
        #expect(!core.guiConfigStore.exists)
    }

    @Test("an unreadable sidecar is refused, never overwritten")
    func unreadableSidecarRefused() throws {
        let garbage = Data("{ not json".utf8)
        let model = try makeModel(sidecarBytes: garbage)
        model.config.profileBindings[.number(2)] = DesktopBinding(
            profile: "Away",
            desktop: 2
        )

        model.saveEditedProfile()

        #expect(
            try Data(contentsOf: model.core.guiConfigStore.url)
                == garbage
        )
        #expect(model.profileWarning != nil)
    }
}
