import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A lens's shortcut row (#2103 rulings 11, 28, 39, 42): Settings
/// draws one per live lens, bound or not; the overview lists the
/// bound ones beside Toggle KiwiVision; a chip draws its lens's
/// chord; and a rename or delete re-keys or frees the stored rows.
@Suite("Shortcuts ▸ lens rows", .serialized)
@MainActor
struct ShortcutsLensRowsTests {
    private func expander(_ lenses: [String]) -> ShortcutsFamilyRows {
        ShortcutsFamilyRows(
            spaces: [],
            icons: [:],
            desktops: .none,
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName],
            currentLayer: KeyLayer.defaultName,
            lenses: lenses
        )
    }

    private func binding(_ lua: String, _ combo: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .navigation)
    }

    @Test("every live lens gets a row, a quote in its name escaped")
    func rowPerLens() throws {
        LocalizationManager.shared.select("en")
        let rows = try #require(
            expander(["Writing", #"Say "hi""#]).rows(
                for: .shortcuts(.toggleLens)
            )
        )
        try #require(rows.count == 2)
        #expect(
            rows.map(\.lua) == [
                #"kiwivision.toggle("Writing")"#,
                #"kiwivision.toggle("Say \"hi\"")"#,
            ]
        )
        #expect(
            rows.map(\.resolvedLabel) == [
                "Toggle Writing lens", #"Toggle Say "hi" lens"#,
            ]
        )
        #expect(KeybindingCatalog.lensTarget(of: rows[1].lua) == #"Say "hi""#)
        #expect(
            KeybindingCatalog.lensTarget(
                of: KeybindingCatalog.toggleKiwiVision.lua
            ) == nil
        )
        #expect(
            expander([]).rows(for: .shortcuts(.toggleLens))?.isEmpty == true
        )
    }

    @Test("the overview lists a bound lens beside Toggle KiwiVision")
    func overviewListsBoundLenses() throws {
        LocalizationManager.shared.select("en")
        let lens = KeybindingCatalog.toggleLens("Writing")
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [binding(lens.lua, "control+option+w")]
            ),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName],
            lenses: ["Writing", "Mail"]
        )
        let section = try #require(
            reference.controls.first { $0.title == "KiwiVision" }
        )
        #expect(section.rows.map(\.id) == [lens.lua])
    }

    @Test("a lens chip draws its own chord")
    func chipDrawsItsChord() throws {
        LocalizationManager.shared.select("en")
        let items = JumpPanelController.items(
            layout: nil,
            profiles: (nil, [], []),
            vision: (
                .off,
                [
                    VisionLensChoice(name: "Writing", refusal: nil),
                    VisionLensChoice(name: "Mail", refusal: nil),
                ]
            ),
            visionChord: "⌃⌥V",
            lensChord: { $0 == "Writing" ? "⌃⌥W" : nil },
            inert: nil
        )
        let vision = try #require(items[.vision])
        #expect(vision.first { $0.name == "Writing" }?.chord == "⌃⌥W")
        #expect(vision.first { $0.name == "Mail" }?.chord == nil)
    }

    @Test("a rename re-keys its rows, ignoring case; others stay")
    func renameRekeys() {
        let layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    binding(#"kiwivision.toggle("writing")"#, "control+w"),
                    binding(
                        KeybindingCatalog.toggleKiwiVision.lua,
                        "control+v"
                    ),
                    binding(
                        KeybindingCatalog.toggleLens("Mail").lua,
                        "control+m"
                    ),
                ]
            )
        ]
        let renamed = KeybindingCatalog.renameLens(
            in: layers,
            from: "Writing",
            to: "Draft"
        )
        #expect(
            renamed[0].bindings.map(\.lua) == [
                KeybindingCatalog.toggleLens("Draft").lua,
                KeybindingCatalog.toggleKiwiVision.lua,
                KeybindingCatalog.toggleLens("Mail").lua,
            ]
        )
        #expect(renamed[0].bindings[0].label == "Toggle Draft lens")
        #expect(renamed[0].bindings[0].combo == "control+w")
    }

    @Test("a rename over a stale row keeps the lens's own chord")
    func renameKeepsOneChord() {
        let layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    binding(
                        KeybindingCatalog.toggleLens("Writing").lua,
                        "control+w"
                    ),
                    binding(
                        KeybindingCatalog.toggleLens("Draft").lua,
                        "control+d"
                    ),
                ]
            )
        ]
        let renamed = KeybindingCatalog.renameLens(
            in: layers,
            from: "Writing",
            to: "Draft"
        )
        #expect(renamed[0].bindings.map(\.combo) == ["control+w"])
        #expect(
            renamed[0].bindings.map(\.lua)
                == [KeybindingCatalog.toggleLens("Draft").lua]
        )
        // A new spelling of the same name keeps its row.
        let respelled = KeybindingCatalog.renameLens(
            in: layers,
            from: "Writing",
            to: "WRITING"
        )
        #expect(
            respelled[0].bindings.first?.lua
                == KeybindingCatalog.toggleLens("WRITING").lua
        )
    }

    @Test("a rename leaves a layer without the old lens alone")
    func renameLeavesOtherLayers() {
        let layers = [
            KeyLayer(
                name: "other",
                bindings: [
                    binding(
                        KeybindingCatalog.toggleLens("Draft").lua,
                        "control+d"
                    )
                ]
            )
        ]
        #expect(
            KeybindingCatalog.renameLens(
                in: layers,
                from: "Writing",
                to: "Draft"
            ) == layers
        )
    }

    @Test("a delete frees its chord and nothing else")
    func deleteFreesTheChord() {
        let layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    binding(
                        KeybindingCatalog.toggleLens("Writing").lua,
                        "control+w"
                    ),
                    binding(
                        KeybindingCatalog.toggleKiwiVision.lua,
                        "control+v"
                    ),
                ]
            )
        ]
        let deleted = KeybindingCatalog.deleteLens(
            in: layers,
            named: "WRITING"
        )
        #expect(
            deleted[0].bindings.map(\.lua)
                == [KeybindingCatalog.toggleKiwiVision.lua]
        )
    }
}
