import AppKit
import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@Suite("Layout Quick Menu and Drift", .serialized)
@MainActor
struct LayoutQuickMenuTests {
    private func makeModel() -> (SettingsModel, KiwiCore) {
        let core = KiwiCore(
            configDirectory: FileManager.default
                .temporaryDirectory
                .appendingPathComponent(
                    "kiwi-layout-test-\(UUID().uuidString)"
                )
        )
        try? core.guiConfigStore.save(GuiConfig())
        return (SettingsModel(core: core), core)
    }

    @Test("Layout menu marks space mode and carries representedObject")
    func layoutMenuCases() throws {
        let (model, core) = makeModel()
        let controller = StatusItemController()

        controller.layoutInfoProvider = {
            (
                activeMode: core.activeSpace?.mode,
                activeProfileName: core.profiles.currentName,
                savedModeForActiveSpace: core.savedModeForActiveSpace()
            )
        }

        // Ensure there is an active space
        core.state.workspaces.ensureSpace(SpaceID("1"))
        core.state.workspaces.setMode(SpaceID("1"), .monocle)

        let item = controller.layoutItem()
        let submenu = try #require(item.submenu)

        // Check that monocle is checked and others are not
        for subitem in submenu.items {
            guard let raw = subitem.representedObject as? String,
                let mode = LayoutMode(rawValue: raw)
            else { continue }

            #expect(
                subitem.action == #selector(
                    StatusItemController.setLayoutMode(_:)
                )
            )
            if mode == .monocle {
                #expect(subitem.state == .on)
            } else {
                #expect(subitem.state == .off)
            }
        }
    }

    @Test("Save Layout to Profile row visibility and enablement")
    func saveLayoutRow() throws {
        let (model, core) = makeModel()
        let controller = StatusItemController()

        controller.layoutInfoProvider = {
            (
                activeMode: core.activeSpace?.mode,
                activeProfileName: core.profiles.currentName,
                savedModeForActiveSpace: core.savedModeForActiveSpace()
            )
        }

        core.state.workspaces.ensureSpace(SpaceID("1"))

        // Case 1: No active profile -> Save row hidden
        #expect(core.profiles.currentName == nil)
        let item1 = controller.layoutItem()
        let submenu1 = try #require(item1.submenu)
        let saveRow1 = submenu1.items.first {
            $0.action == #selector(
                StatusItemController.saveLayoutToProfile(_:)
            )
        }
        #expect(saveRow1 == nil)

        // Case 2: Active profile present, but live == saved -> disabled
        let profile = Profile(
            name: "test-profile",
            monitorSets: [],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): .bsp],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("test-profile")]
        )

        #expect(core.profiles.currentName == "test-profile")
        core.state.workspaces.setMode(SpaceID("1"), .bsp)

        let item2 = controller.layoutItem()
        let submenu2 = try #require(item2.submenu)
        let saveRow2 = try #require(
            submenu2.items.first {
                $0.action == #selector(
                    StatusItemController.saveLayoutToProfile(_:)
                )
            }
        )
        #expect(!saveRow2.isEnabled)

        // Case 3: Active profile present, live != saved -> enabled
        core.state.workspaces.setMode(SpaceID("1"), .monocle)

        let item3 = controller.layoutItem()
        let submenu3 = try #require(item3.submenu)
        let saveRow3 = try #require(
            submenu3.items.first {
                $0.action == #selector(
                    StatusItemController.saveLayoutToProfile(_:)
                )
            }
        )
        #expect(saveRow3.isEnabled)
    }

    @Test("Drift computation does not set dirty flags")
    func driftComputationFlags() throws {
        let (model, core) = makeModel()

        core.state.workspaces.ensureSpace(SpaceID("1"))

        let profile = Profile(
            name: "test-profile",
            monitorSets: [],
            spaces: [SpaceID("1")],
            spaceModes: [SpaceID("1"): .bsp],
            settings: TilingSettings()
        )
        try core.profiles.save(profile)
        _ = core.execute(
            "load_profile",
            args: [.string("test-profile")]
        )
        model.reload()

        #expect(!model.isDirty)
        #expect(!model.profileDirty)
        #expect(!model.hasLayoutDrift)

        // Introduce drift
        core.state.workspaces.setMode(SpaceID("1"), .monocle)
        model.reload()  // reload view state

        #expect(model.hasLayoutDrift)
        // Guardrail 3: must NOT set isDirty or profileDirty
        #expect(!model.isDirty)
        #expect(!model.profileDirty)
    }
}
