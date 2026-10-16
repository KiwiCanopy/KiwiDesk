import Foundation
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

    private func censusRows(
        _ tier: SettingTier
    ) -> Set<SettingKey> {
        Set(
            SettingKey.allCases.filter {
                $0.placement.area == .shortcuts
                    && $0.placement.container == .kiwiVisionShortcuts
                    && $0.placement.tier == tier
            }
        )
    }

    /// The group's one tier is the census's, so a lens key placed
    /// in the container and left off the list reds here.
    @Test("KiwiVision's one tier is the census's")
    func kiwiVisionTier() {
        let keys = ShortcutsRowOrder.kiwiVisionAtRest
        #expect(Set(keys) == censusRows(.atRest))
        #expect(keys.count == Set(keys).count)
        #expect(keys.contains(.shortcuts(.toggleKiwiVision)))
        #expect(censusRows(.showMore).isEmpty)
        #expect(censusRows(.immediate).isEmpty)
        #expect(
            !ShortcutsRowOrder.focusAtRest.contains(
                .shortcuts(.toggleKiwiVision)
            )
        )
    }

    /// The group draws its WHOLE list, and the section mounts it.
    @Test("KiwiVision draws every row")
    func rowsAreAllDrawn() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
        func squeezed(_ file: String) throws -> String {
            SourceScan.stripComments(
                try String(
                    contentsOf: root.appendingPathComponent(file),
                    encoding: .utf8
                )
            )
            .split(whereSeparator: \.isWhitespace)
            .joined()
        }
        let group = try #require(
            SourceScan.declarationBody(
                after: "structKiwiVisionShortcutsGroup",
                in: try squeezed(
                    "Components/Keybindings/KiwiVisionShortcutsGroup.swift"
                )
            )
        )
        #expect(
            group.contains(
                "ForEach(ShortcutsRowOrder.kiwiVisionAtRest,id:\\.id)"
            )
        )
        let section = try squeezed("Sections/ShortcutsSection.swift")
        #expect(section.occurrences(of: "KiwiVisionShortcutsGroup(") == 1)
    }
}
