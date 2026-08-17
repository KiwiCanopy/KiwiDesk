import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Fake menu-bar slot so this suite never registers a real
/// system status item (#565 seam class);
/// `StatusItemSeamGuardTests` pins that every test
/// construction injects one.
@MainActor
private final class FakeStatusItem: StatusItemHandle {
    let button: NSStatusBarButton? = nil
    var menu: NSMenu?
}

@Suite("Layout Quick Menu and Drift", .serialized)
@MainActor
struct LayoutQuickMenuTests {
    private func makeModel() -> (SettingsModel, KiwiCore) {
        // makeTestCore's default registrar is already the no-op
        // (#565) — this suite asserts nothing about registration.
        let core = makeTestCore()
        try? core.guiConfigStore.save(GuiConfig())
        return (makeTestModel(core: core), core)
    }

    private func makeController(
        _ core: KiwiCore
    ) -> StatusItemController {
        let controller = StatusItemController(
            item: FakeStatusItem()
        )
        controller.layoutInfoProvider = {
            LayoutMenuInfo.current(from: core)
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
            guard
                let target = entry.representedObject
                    as? LayoutMenuTarget
            else { return nil }
            return (entry, target.mode)
        }
        // Every case present, every entry carrying its mode in
        // representedObject (titles are localized — guardrail).
        #expect(modeEntries.count == LayoutMode.allCases.count)
        // #752's flat-menu promise — for the **zero**-screen arm
        // specifically, which is what this fixture is: it upserts
        // no `Display`, so `screens == []`. That arm is real and
        // worth holding (`allDisplays` is briefly empty while a
        // display change settles, and the menu must still answer
        // for the active space), but it is NOT the one-screen
        // boundary — `LayoutScreensQuickMenuTests.oneScreenStaysFlat`
        // owns that. `guard-prover` caught this comment claiming
        // otherwise: mutating the threshold to `>= 1` left this
        // test green (2026-08-17).
        #expect(LayoutMenuInfo.current(from: core).screens.isEmpty)
        #expect(!LayoutMenuInfo.current(from: core).nestsPerScreen)
        #expect(submenu.items.allSatisfy { $0.submenu == nil })
        // Enablement is stated, so a row cannot ship explicitly
        // dimmed. Read as the explicit-disable direction ONLY:
        // `NSMenuItem.isEnabled` defaults to true, so this cannot
        // see a row that forgot to state it, which is what #802
        // actually costs — `LayoutMenuEnablementScanTests` guards
        // the omission in the source, where it is visible.
        #expect(modeEntries.allSatisfy { $0.0.isEnabled })

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
