import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiVision's shortcuts are a section of their own (#2312), in
/// the overview as in Settings: a view mode is no Focus verb, and
/// a section with no bound key is dropped.
@Suite("Shortcuts ▸ KiwiVision section", .serialized)
@MainActor
struct ShortcutsKiwiVisionSectionTests {
    private func build(_ bindings: [KeyBinding]) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [SpaceID("1")],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
    }

    private var toggle: KeyBinding {
        KeyBinding(
            combo: "control+option+v",
            lua: KeybindingCatalog.toggleKiwiVision.lua,
            kind: .navigation
        )
    }

    private var focusLeft: KeyBinding {
        KeyBinding(
            combo: "control+option+left",
            lua: KeybindingCatalog.focusDirections[0].lua,
            kind: .navigation
        )
    }

    @Test("the toggle stands in its own section, never under Focus")
    func ownSection() throws {
        LocalizationManager.shared.select("en")
        let reference = build([focusLeft, toggle])
        let section = try #require(
            reference.controls.first { $0.title == "KiwiVision" }
        )
        #expect(
            section.rows.map(\.id) == [KeybindingCatalog.toggleKiwiVision.lua]
        )
        let focus = try #require(
            reference.controls.first { $0.title == "Focus" }
        )
        #expect(
            !focus.rows.map(\.id).contains(
                KeybindingCatalog.toggleKiwiVision.lua
            )
        )
    }

    @Test("with no KiwiVision key bound, no section")
    func droppedWhenUnbound() {
        LocalizationManager.shared.select("en")
        #expect(
            !build([focusLeft]).controls.contains { $0.title == "KiwiVision" }
        )
    }

    @Test("Settings files the toggle in the KiwiVision container")
    func censusPlacement() {
        #expect(
            SettingKey.shortcuts(.toggleKiwiVision).placement.container
                == .kiwiVisionShortcuts
        )
        #expect(
            ShortcutsRowOrder.kiwiVisionAtRest
                == [.shortcuts(.toggleKiwiVision)]
        )
        #expect(
            !ShortcutsRowOrder.focusAtRest.contains(
                .shortcuts(.toggleKiwiVision)
            )
        )
    }
}
