import Foundation
import Testing

@testable import KiwiDeskCore

/// Tests for `KiwiCore.copyProfile(named:to:with:)` — "Save
/// copy as…" in stored-profile edit mode (#82). The copy's
/// source is the stored profile JSON plus the pending edit
/// session, never live state (`buildProfile` would snapshot
/// live tiling and drop the `modes` override).
@Suite("Profile copy (Save copy as…, #82)", .serialized)
@MainActor
struct ProfileCopyTests {

    // MARK: - Helpers

    private func makeGuiCore() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-copy-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+h",
                        lua: "focus_left",
                        kind: .custom,
                        label: ""
                    )
                ]
            )
        ]
        // A failed sidecar write would silently flip the diff
        // base to the live seed — fail the test instead.
        try core.guiConfigStore.save(config)
        return core
    }

    /// A source profile for OTHER hardware (a monitor set that
    /// is not connected in tests), marked count-default, with
    /// a keybinding override.
    private func sourceProfile() -> Profile {
        Profile(
            name: "Dock",
            monitorSets: [
                MonitorSet(monitors: [
                    "LG:2560x1440", "Dell:1920x1080",
                ])
            ],
            isDefault: true,
            spaces: [SpaceID("code"), SpaceID("web")],
            spaceModes: [SpaceID("code"): .stack],
            settings: TilingSettings(),
            modes: KeyModeOverride(
                modes: [
                    KeyMode(
                        name: "default",
                        bindings: [
                            KeyBinding(
                                combo: "alt+h",
                                lua: "OVERRIDE",
                                kind: .custom,
                                label: ""
                            )
                        ]
                    )
                ]
            )
        )
    }

    // MARK: - What the copy carries

    @Test("Copy carries monitor sets, override, spaces; not default")
    func copyCarriesStoredState() throws {
        let core = try makeGuiCore()
        try core.profiles.save(sourceProfile())
        let edited = try core.loadGuiConfig(editing: "Dock")

        let created = try core.copyProfile(
            named: "Dock",
            to: "Dock Copy",
            with: edited
        )

        #expect(created == "Dock Copy")
        let copy = try core.profiles.read(name: "Dock Copy")
        // Other-hardware monitor sets survive the copy
        // (fingerprints are stored normalized/sorted).
        #expect(
            copy.monitorSets.map(\.monitors) == [
                ["Dell:1920x1080", "LG:2560x1440"]
            ]
        )
        // The sparse keybinding override survives.
        #expect(copy.modes == sourceProfile().modes)
        // Spaces and modes survive.
        #expect(copy.spaces == sourceProfile().spaces)
        #expect(copy.spaceModes[SpaceID("code")] == .stack)
        // The count-default flag must NOT be duplicated.
        #expect(!copy.isDefault)
    }

    @Test("Copy of the Starter ladder is not the baseline (#485)")
    func copyClearsStarterLadderFlag() throws {
        let core = try makeGuiCore()
        var starter = sourceProfile()
        starter.name = "Starter"
        starter.isStarterLadder = true
        try core.profiles.save(starter)
        let edited = try core.loadGuiConfig(editing: "Starter")

        try core.copyProfile(
            named: "Starter",
            to: "My Setup",
            with: edited
        )

        // The copy is the user's own profile — the ladder
        // baseline flag must not ride along, or an unmatched
        // monitor change would recompose the ladder over it.
        let copy = try core.profiles.read(name: "My Setup")
        #expect(!copy.isStarterLadder)
        // The source keeps the flag.
        #expect(
            try core.profiles.read(name: "Starter").isStarterLadder
        )
    }

    @Test("Pending edits land in the copy, not the source")
    func pendingEditsLandInCopy() throws {
        let core = try makeGuiCore()
        try core.profiles.save(sourceProfile())
        var edited = try core.loadGuiConfig(editing: "Dock")
        // Rebind alt+h differently in the edit session.
        let at = try #require(
            edited.modes[0].bindings.firstIndex {
                $0.combo == "alt+h"
            }
        )
        edited.modes[0].bindings[at].lua = "EDITED"

        try core.copyProfile(
            named: "Dock",
            to: "Variant",
            with: edited
        )

        let copy = try core.profiles.read(name: "Variant")
        #expect(
            copy.modes?.modes[0].bindings[0].lua == "EDITED"
        )
        // The source keeps its own override untouched.
        let source = try core.profiles.read(name: "Dock")
        #expect(
            source.modes?.modes[0].bindings[0].lua
                == "OVERRIDE"
        )
    }

    // MARK: - Invalid names fail closed

    @Test("Blank or traversal names throw; nothing written")
    func invalidNamesThrow() throws {
        let core = try makeGuiCore()
        try core.profiles.save(sourceProfile())
        let edited = try core.loadGuiConfig(editing: "Dock")
        let before = core.profiles.list()

        for bad in ["   ", "\n", "../evil", ".hidden"] {
            #expect(throws: (any Error).self) {
                try core.copyProfile(
                    named: "Dock",
                    to: bad,
                    with: edited
                )
            }
        }
        #expect(core.profiles.list() == before)
    }

    // MARK: - Non-adopting

    /// NOTE: `profiles.save` in the setup ADOPTS "Dock", so
    /// this test also covers copying while the source is the
    /// ACTIVE profile — keep the adopting save if the helper
    /// changes.
    @Test("Copy adopts nothing and touches no global file")
    func copyIsNonAdopting() throws {
        let core = try makeGuiCore()
        try core.profiles.save(sourceProfile())
        let sidecarURL = core.configDirectory
            .appendingPathComponent("gui.json")
        let sidecarBefore = try Data(contentsOf: sidecarURL)
        let currentBefore = core.profiles.currentName
        let edited = try core.loadGuiConfig(editing: "Dock")

        try core.copyProfile(
            named: "Dock",
            to: "Dock Copy",
            with: edited
        )

        #expect(core.profiles.currentName == currentBefore)
        let sidecarAfter = try Data(contentsOf: sidecarURL)
        #expect(sidecarAfter == sidecarBefore)
    }

    // MARK: - Naming

    @Test("Taken name gets the _1 suffix; result is returned")
    func collisionSuffixed() throws {
        let core = try makeGuiCore()
        try core.profiles.save(sourceProfile())
        let edited = try core.loadGuiConfig(editing: "Dock")

        // "Dock" itself is taken by the source.
        let created = try core.copyProfile(
            named: "Dock",
            to: "Dock",
            with: edited
        )

        #expect(created == "Dock_1")
        #expect(core.profiles.list().contains("Dock_1"))
        // The source is untouched.
        let source = try core.profiles.read(name: "Dock")
        #expect(source.isDefault)
    }
}
