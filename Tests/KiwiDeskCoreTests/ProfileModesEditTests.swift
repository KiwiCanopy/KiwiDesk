import Foundation
import Testing

@testable import KiwiDeskCore

/// Integration tests for editing a stored profile's keybinding
/// override through the GUI path (#55 phase 7):
/// `loadGuiConfig(editing:)` seeds the RESOLVED modes,
/// `overwriteProfile` stores only the sparse diff against the
/// base gui.json modes — and never writes gui.json itself.
@Suite("Profile modes edit round-trip (#55 phase 7)", .serialized)
@MainActor
struct ProfileModesEditTests {

    // MARK: - Helpers

    private func makeGuiCore() -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-modesedit-\(UUID().uuidString)"
                )
        )
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: "default",
                bindings: [
                    KeyBinding(
                        combo: "alt+p",
                        lua: "load_profile",
                        kind: .custom,
                        label: ""
                    ),
                    KeyBinding(
                        combo: "alt+h",
                        lua: "focus_left",
                        kind: .custom,
                        label: ""
                    ),
                ]
            )
        ]
        try? core.guiConfigStore.save(config)
        return core
    }

    private func saveWorkProfile(
        _ core: KiwiCore,
        modes: KeyModeOverride? = nil
    ) throws {
        try core.profiles.save(
            Profile(
                name: "Work",
                monitorSets: [
                    MonitorSet(monitors: ["A:100x100"])
                ],
                spaceModes: [:],
                settings: TilingSettings(),
                modes: modes
            )
        )
    }

    private var override: KeyModeOverride {
        KeyModeOverride(
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
    }

    // MARK: - Seeding

    @Test("loadGuiConfig(editing:) seeds the RESOLVED modes")
    func editingSeedsResolvedModes() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, modes: override)

        let config = try core.loadGuiConfig(editing: "Work")

        let rows = config.modes[0].bindings
        // Overridden combo shows the profile's action…
        #expect(
            rows.first { $0.combo == "alt+h" }?.lua
                == "OVERRIDE"
        )
        // …and the inherited switch key shows the base's.
        #expect(
            rows.first { $0.combo == "alt+p" }?.lua
                == "load_profile"
        )
    }

    // MARK: - Saving

    @Test("overwriteProfile stores the sparse diff only")
    func overwriteStoresSparseDiff() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core)

        var config = try core.loadGuiConfig(editing: "Work")
        let at = config.modes[0].bindings.firstIndex {
            $0.combo == "alt+h"
        }
        config.modes[0].bindings[try #require(at)].lua =
            "OVERRIDE"
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        let stored = try #require(saved.modes)
        #expect(stored.modes.count == 1)
        #expect(stored.modes[0].bindings.count == 1)
        #expect(stored.modes[0].bindings[0].combo == "alt+h")
        #expect(stored.modes[0].bindings[0].lua == "OVERRIDE")
    }

    @Test("Unchanged edit session preserves the override")
    func unchangedSavePreservesOverride() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, modes: override)

        // Load for edit and save straight back.
        let config = try core.loadGuiConfig(editing: "Work")
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.modes == override)
    }

    @Test("Reverting to base clears the override (nil, sparse)")
    func revertingClearsOverride() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core, modes: override)

        var config = try core.loadGuiConfig(editing: "Work")
        // Put the overridden row back to its base action.
        let at = config.modes[0].bindings.firstIndex {
            $0.combo == "alt+h"
        }
        config.modes[0].bindings[try #require(at)].lua =
            "focus_left"
        try core.overwriteProfile(named: "Work", with: config)

        let saved = try core.profiles.read(name: "Work")
        #expect(saved.modes == nil)
        // O3: the cleared override encodes as key ABSENT.
        let data = try JSONEncoder().encode(saved)
        let json = try #require(
            String(data: data, encoding: .utf8)
        )
        #expect(!json.contains("\"modes\""))
    }

    @Test("overwriteProfile never writes gui.json")
    func overwriteLeavesSidecarAlone() throws {
        let core = makeGuiCore()
        try saveWorkProfile(core)
        let sidecarURL = core.configDirectory
            .appendingPathComponent("gui.json")
        let before = try Data(contentsOf: sidecarURL)

        var config = try core.loadGuiConfig(editing: "Work")
        config.modes[0].bindings[0].lua = "CHANGED"
        try core.overwriteProfile(named: "Work", with: config)

        let after = try Data(contentsOf: sidecarURL)
        #expect(after == before)
    }
}
