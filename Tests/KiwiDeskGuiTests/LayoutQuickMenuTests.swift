import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// No-op so this GUI suite never registers real global chords
/// (#565); the Core target's `NoopHotkeyRegistrar` is not visible
/// here, and the Gui convention is a per-file fake.
private final class NoopRegistrar: HotkeyRegistrar {
    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? { 1 }
    func unregister(id: UInt32) {}
}

@Suite("Layout Quick Menu and Drift", .serialized)
@MainActor
struct LayoutQuickMenuTests {
    private func makeModel() -> (SettingsModel, KiwiCore) {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-layout-test-\(UUID().uuidString)"
                ),
            hotkeyRegistrar: NoopRegistrar()
        )
        try? core.guiConfigStore.save(GuiConfig())
        return (SettingsModel(core: core), core)
    }

    private func makeController(
        _ core: KiwiCore
    ) -> StatusItemController {
        let controller = StatusItemController()
        controller.layoutInfoProvider = {
            (
                activeMode: core.activeSpace?.mode,
                activeProfileName: core.profiles.currentName,
                savedModeForActiveSpace:
                    core.savedModeForActiveSpace()
            )
        }
        return controller
    }

    private func loadProfile(
        _ core: KiwiCore,
        mode: LayoutMode = .bsp
    ) throws {
        // A valid monitor set is required (decode rejects a
        // profile without one) and it must match a live
        // display, or `load_profile` marks the profile dirty
        // (#36) and the guardrail-3 assertions turn vacuous.
        let frame = CGRect(x: 0, y: 0, width: 100, height: 100)
        core.state.workspaces.upsertDisplay(
            Display(
                id: DisplayID(1),
                name: "A",
                frame: frame,
                visibleFrame: frame
            )
        )
        let profile = Profile(
            name: "test-profile",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): mode],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("test-profile")]
        )
    }

    private func saveRow(in submenu: NSMenu) -> NSMenuItem? {
        submenu.items.first {
            $0.action
                == #selector(
                    StatusItemController.saveLayoutToProfile(_:)
                )
        }
    }

    @Test("Layout menu marks space mode, carries representedObject")
    func layoutMenuCases() throws {
        let (_, core) = makeModel()
        let controller = makeController(core)

        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.setMode(SpaceID("1"), .monocle)

        let item = controller.layoutItem()
        let submenu = try #require(item.submenu)
        // Manual enablement must stay on: auto-enable would
        // re-enable the save row at display time.
        #expect(!submenu.autoenablesItems)

        let modeEntries = submenu.items.compactMap {
            entry -> (NSMenuItem, LayoutMode)? in
            guard let raw = entry.representedObject as? String,
                let mode = LayoutMode(rawValue: raw)
            else { return nil }
            return (entry, mode)
        }
        // Every case present, every entry carrying its mode in
        // representedObject (titles are localized — guardrail).
        #expect(modeEntries.count == LayoutMode.allCases.count)

        for (entry, mode) in modeEntries {
            #expect(
                entry.action
                    == #selector(
                        StatusItemController.setLayoutMode(_:)
                    )
            )
            #expect(
                entry.state == (mode == .monocle ? .on : .off)
            )
        }
        let checkedCount = modeEntries.filter {
            $0.0.state == .on
        }.count
        #expect(checkedCount == 1)
    }

    @Test("Save row hidden without profile, enablement by drift")
    func saveLayoutRow() throws {
        let (_, core) = makeModel()
        let controller = makeController(core)

        core.state.workspaces.ensureSpace(SpaceID("1"))

        // No active profile: save row hidden.
        #expect(core.profiles.currentName == nil)
        let submenu1 = try #require(
            controller.layoutItem().submenu
        )
        #expect(saveRow(in: submenu1) == nil)

        // Active profile, live == saved: disabled.
        try loadProfile(core)
        #expect(core.profiles.currentName == "test-profile")
        core.state.workspaces.setMode(SpaceID("1"), .bsp)
        let submenu2 = try #require(
            controller.layoutItem().submenu
        )
        let saveRow2 = try #require(saveRow(in: submenu2))
        #expect(!saveRow2.isEnabled)

        // Live != saved: enabled.
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        let submenu3 = try #require(
            controller.layoutItem().submenu
        )
        let saveRow3 = try #require(saveRow(in: submenu3))
        #expect(saveRow3.isEnabled)
    }

    @Test("Checked entry carries drift subtitle only when drifted")
    func driftSubtitle() throws {
        guard #available(macOS 14.4, *) else { return }
        let (_, core) = makeModel()
        let controller = makeController(core)

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)

        // No drift: no subtitle on the checked entry.
        core.state.workspaces.setMode(SpaceID("1"), .bsp)
        let clean = try #require(
            controller.layoutItem().submenu
        )
        let cleanChecked = try #require(
            clean.items.first { $0.state == .on }
        )
        #expect(cleanChecked.subtitle == nil)

        // Drift: the checked entry announces it.
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        let drifted = try #require(
            controller.layoutItem().submenu
        )
        let driftedChecked = try #require(
            drifted.items.first { $0.state == .on }
        )
        #expect(driftedChecked.subtitle?.isEmpty == false)
    }

    @Test("Drift computation does not set dirty flags")
    func driftComputationFlags() throws {
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        model.reload()

        #expect(!model.isDirty)
        #expect(!model.profileDirty)
        #expect(!model.hasLayoutDrift)

        // Introduce drift.
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        model.reload()

        #expect(model.hasLayoutDrift)
        #expect(model.layoutDrift?.live == .monocle)
        #expect(model.layoutDrift?.saved == .bsp)
        // Guardrail 3: never routed through the dirty flags.
        #expect(!model.isDirty)
        #expect(!model.profileDirty)
    }

    @Test("Unreadable profile reads as unknown, never as drift")
    func unreadableProfileNoDrift() throws {
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        core.state.workspaces.setMode(SpaceID("1"), .monocle)

        // Corrupt the saved JSON: the saved mode is now
        // unknown — no phantom `.bsp`, no phantom drift.
        try Data("not json".utf8).write(
            to: core.configURL
                .deletingLastPathComponent()
                .appendingPathComponent(
                    "profiles/test-profile.json"
                )
        )
        #expect(core.savedModeForActiveSpace() == nil)
        model.reload()
        #expect(!model.hasLayoutDrift)
    }

    @Test("refreshLayoutDrift keeps staged edits intact")
    func refreshKeepsStagedEdits() throws {
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))
        try loadProfile(core)
        model.reload()

        // Stage an edit, then drift the live layout and take
        // the non-destructive refresh path the quick menu uses.
        model.config.spaces.append(SpaceID("staged"))
        #expect(model.isDirty)

        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        model.refreshLayoutDrift()

        #expect(model.hasLayoutDrift)
        #expect(model.isDirty)
        #expect(
            model.config.spaces.contains(SpaceID("staged"))
        )
    }
}
