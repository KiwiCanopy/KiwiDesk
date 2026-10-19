import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// KiwiVision's shortcuts are a section of their own in the
/// overview (#2312) and a sub-group of Show & hide in Settings: a
/// view mode is no Focus verb, and a section with no bound key is
/// dropped.
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

    /// The toggle is a Show & hide row, never a Focus verb, and
    /// every row on the KiwiVision list sits in that card
    /// (`ShowHideCensusRenderTests` holds the card whole).
    @Test("KiwiVision's rows sit in Show & hide")
    func kiwiVisionTier() {
        let keys = ShortcutsRowOrder.kiwiVisionAtRest
        #expect(keys.contains(.shortcuts(.toggleKiwiVision)))
        #expect(
            keys.allSatisfy {
                $0.placement.container == .showHide
                    && $0.placement.tier == .atRest
            }
        )
        #expect(
            !ShortcutsRowOrder.focusAtRest.contains(
                .shortcuts(.toggleKiwiVision)
            )
        )
    }
}
