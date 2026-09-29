import CoreGraphics
import Foundation
import Testing

@testable import KiwiDeskCore

/// The top-up counts `gui.json`'s shared base and every stored
/// profile's override, so a Space verb any profile binds is never
/// given a second chord, and a row a profile removes is never
/// appended again (#1797).
@Suite("Digit top-up reads the resolved layer (#1797)", .serialized)
@MainActor
struct DigitTopUpOverrideTests {
    private func onStarterBaseline() throws -> KiwiCore {
        let core = makeTestCore(
            configDirectory: FileManager.default.temporaryDirectory
                .appendingPathComponent(
                    "kiwi-topup-override-\(UUID().uuidString)"
                )
        )
        try core.guiConfigStore.save(GuiConfig())
        let screen = Display(
            id: DisplayID(1),
            name: "A",
            frame: CGRect(x: 0, y: 0, width: 100, height: 100)
        )
        core.state.workspaces.upsertDisplay(screen)
        try core.applyStandard(
            StarterSetup.standardLayout(
                displays: [screen],
                mainID: DisplayID(1)
            )
        )
        return core
    }

    private func baseRows(_ core: KiwiCore) -> [KeyBinding] {
        core.persistedGuiConfig()?.layers
            .first { $0.isDefault }?.bindings ?? []
    }

    @Test("a verb the profile override binds is not topped up")
    func overrideBoundVerbIsSkipped() throws {
        let core = try onStarterBaseline()
        let name = try #require(core.profiles.currentName)
        var profile = try core.profiles.read(name: name)
        let goToFour = "KiwiDesk.focus_space(\"4\")"
        profile.layers = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: KeyLayer.defaultName,
                    bindings: [
                        KeyBinding(
                            combo: "control+option+f4",
                            lua: goToFour,
                            kind: .navigation,
                            label: "Go to Space 4"
                        )
                    ]
                )
            ]
        )
        try core.profiles.write(profile)
        core.state.workspaces.ensureSpace(SpaceID("4"))

        core.topUpDigitShortcuts()

        let rows = baseRows(core)
        // Vacuity: the top-up ran and reached Space 4.
        #expect(
            rows.contains {
                $0.lua == "KiwiDesk.move_to_space(\"4\")"
            }
        )
        #expect(!rows.contains { $0.lua == goToFour })
    }

    @Test("a base row a profile removes is not added again")
    func tombstonedRowIsNotReAdded() throws {
        let core = try onStarterBaseline()
        let name = try #require(core.profiles.currentName)
        var profile = try core.profiles.read(name: name)
        profile.layers = KeyLayerOverride(
            removed: [KeyLayer.defaultName: ["control+option+3"]]
        )
        try core.profiles.write(profile)
        let before = baseRows(core).count

        core.topUpDigitShortcuts()
        core.topUpDigitShortcuts()

        #expect(baseRows(core).count == before)
    }

    @Test("a verb another profile's override binds is not topped up")
    func otherProfileBoundVerbIsSkipped() throws {
        let core = try onStarterBaseline()
        let goToFour = "KiwiDesk.focus_space(\"4\")"
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [MonitorSet(monitors: ["B:1x1"])],
                spaceModes: [:],
                settings: TilingSettings(),
                layers: KeyLayerOverride(
                    layers: [
                        KeyLayer(
                            name: KeyLayer.defaultName,
                            bindings: [
                                KeyBinding(
                                    combo: "control+option+f4",
                                    lua: goToFour,
                                    kind: .navigation,
                                    label: "Go to Space 4"
                                )
                            ]
                        )
                    ]
                )
            )
        )
        core.state.workspaces.ensureSpace(SpaceID("4"))

        core.topUpDigitShortcuts()

        let rows = baseRows(core)
        #expect(
            rows.contains {
                $0.lua == "KiwiDesk.move_to_space(\"4\")"
            }
        )
        #expect(!rows.contains { $0.lua == goToFour })
    }

    @Test("another profile's non-Space chord does not block a digit")
    func otherProfileComboDoesNotBlock() throws {
        let core = try onStarterBaseline()
        try core.profiles.write(
            Profile(
                name: "Other",
                monitorSets: [MonitorSet(monitors: ["B:1x1"])],
                spaceModes: [:],
                settings: TilingSettings(),
                layers: KeyLayerOverride(
                    layers: [
                        KeyLayer(
                            name: KeyLayer.defaultName,
                            bindings: [
                                KeyBinding(
                                    combo: "control+option+4",
                                    lua: "KiwiDesk.toggle_floating()"
                                )
                            ]
                        )
                    ]
                )
            )
        )
        core.state.workspaces.ensureSpace(SpaceID("4"))

        core.topUpDigitShortcuts()

        #expect(
            baseRows(core).contains {
                $0.combo == "control+option+4"
                    && $0.lua == "KiwiDesk.focus_space(\"4\")"
            }
        )
    }
}
