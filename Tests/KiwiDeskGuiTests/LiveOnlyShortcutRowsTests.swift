import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

/// Temporary and held Spaces in the per-Space shortcut rows
/// (#1827): drawn after the profile's own, temporary first, each
/// wearing its chip; every surface asking "is this chord inactive"
/// judges against the same reading; and a drop of a gone Space's
/// shortcuts reaches a draft of any target.
@Suite("Live-only Space shortcut rows (#1827)", .serialized)
@MainActor
struct LiveOnlyShortcutRowsTests {
    private let temporary = LiveOnlySpace(
        id: SpaceID("12"),
        kind: .temporary,
        mode: .bsp,
        icon: nil,
        canAdd: true
    )
    private let held = LiveOnlySpace(
        id: SpaceID("14"),
        kind: .held(screen: "DELL", profile: "Work"),
        mode: .bsp,
        icon: nil,
        canAdd: false
    )

    @Test("the per-Space rows add live-only Spaces, temporary first")
    func rowsAddLiveOnlySpaces() throws {
        let expander = ShortcutsFamilyRows(
            spaces: [SpaceID("1")],
            icons: [:],
            liveOnly: [held, temporary],
            desktops: .none,
            resizeStep: 50,
            layerNames: [],
            currentLayer: KeyLayer.defaultName
        )
        let rows = try #require(expander.rows(for: .shortcuts(.goToSpace)))
        #expect(
            rows.map(\.lua) == [
                "KiwiDesk.focus_space(\"1\")",
                "KiwiDesk.focus_space(\"12\")",
                "KiwiDesk.focus_space(\"14\")",
            ]
        )
        #expect(rows.map(\.liveOnly) == [nil, temporary.kind, held.kind])
        #expect(expander.liveSpaces.map(\.raw) == ["1", "12", "14"])
    }

    @Test("a stored profile's page lists no live-only Space")
    func storedPageListsNone() {
        let model = makeTestModel()
        model.liveOnlySpaces = [held, temporary]
        #expect(model.liveOnlyShortcutSpaces.map(\.id.raw) == ["12", "14"])
        model.target = .storedProfile("Other")
        #expect(model.liveOnlyShortcutSpaces.isEmpty)
    }

    @Test("every inactive judge takes the one reading")
    func judgesShareTheReading() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        let sites = [
            "Shortcuts/ShortcutsPanelController+Reference.swift":
                "liveOnlySpaces.shortcutSpaces(",
            "Settings/SettingsModel+Reset.swift":
                "liveOnlyShortcutSpaces.shortcutSpaces(",
            "Settings/Sections/ShortcutsSection.swift":
                "spaces: expander.liveSpaces",
        ]
        for (file, needle) in sites {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(file)
            )
            #expect(source.contains(needle), "\(file) judges by hand")
        }
    }

    @Test("a dirty stored draft drops a gone Space's rows both sides")
    func storedDraftTakesTheDrop() {
        let model = makeTestModel()
        let row = KeyBinding(
            combo: "control+option+9",
            lua: "KiwiDesk.focus_space(\"9\")",
            kind: .navigation,
            label: "Go to Space 9"
        )
        model.config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [row])
        ]
        model.cleanConfig.layers = model.config.layers
        model.target = .storedProfile("Other")
        model.config.settings.resizeStep += 5
        model.recomputeDirty()
        #expect(model.isDirty)
        model.profileEditingBaseLayers = []
        model.adoptShortcutDrop([SpaceID("9")])
        // The base its Save diffs the override against is re-read.
        #expect(
            model.profileEditingBaseLayers == model.core.baseKeyLayers()
        )
        #expect(model.config.layers.allSatisfy { $0.bindings.isEmpty })
        #expect(
            model.cleanConfig.layers.allSatisfy { $0.bindings.isEmpty }
        )
        #expect(model.isDirty)
    }
}
