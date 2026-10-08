import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// #2016: deleting a layer deletes every row that switches to it,
/// and a switch row to a layer no longer listed is drawn as
/// inactive so it can be removed. Only that name is deleted: a
/// switch row to a layer `init.lua` defines reads as dangling to
/// the GUI config.
@Suite("Layer delete (#2016)")
struct LayerDeleteTests {
    private func switchRow(_ name: String) -> KeyBinding {
        let cmd = KeybindingCatalog.switchLayerCommand(name)
        return KeyBinding(
            combo: "alt+\(name.prefix(1))",
            lua: cmd.lua,
            kind: .navigation,
            label: cmd.label
        )
    }

    @Test("a deleted layer takes its switch rows with it")
    func deleteDropsSwitchRows() {
        var base = KeyLayer(name: KeyLayer.defaultName)
        base.bindings = [switchRow("focus"), switchRow("lua-only")]
        var focus = KeyLayer(name: "focus")
        focus.bindings = [switchRow(KeyLayer.defaultName)]
        var other = KeyLayer(name: "other")
        other.bindings = [switchRow("focus")]
        let out = KeybindingCatalog.deleteLayer(
            in: [base, focus, other],
            named: "focus"
        )
        #expect(out.map(\.name) == [KeyLayer.defaultName, "other"])
        #expect(
            out[0].bindings.map(\.lua)
                == [KeybindingCatalog.switchLayerCommand("lua-only").lua]
        )
        #expect(out[1].bindings.isEmpty)
    }

    @Test("the base layer is never deleted")
    func baseLayerStays() {
        let base = KeyLayer(name: KeyLayer.defaultName)
        let out = KeybindingCatalog.deleteLayer(
            in: [base],
            named: KeyLayer.defaultName
        )
        #expect(out == [base])
    }

    /// The header's Delete takes the model's delete, which takes the
    /// catalog's, or the rows survive the layer again (#2022 moved
    /// the delete onto the model, where it records its reach).
    @Test("the header deletes through the catalog")
    func headerTakesTheCatalogDelete() throws {
        let root = SourceScan.repoRoot(from: #filePath)
        func count(_ path: String, _ needle: String) throws -> Int {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            )
            return source.components(separatedBy: needle).count - 1
        }
        let settings = "Sources/KiwiDesk/Settings/"
        #expect(
            try count(
                settings + "Sections/LayerHeader.swift",
                "model.deleteLayer("
            ) == 1
        )
        #expect(
            try count(
                settings + "SettingsModel+LayerReachEdit.swift",
                "KeybindingCatalog.deleteLayer("
            ) == 1
        )
    }

    @Test("a switch row names its layer, any other Lua names none")
    func switchTargetParses() {
        let lua = KeybindingCatalog.switchLayerCommand("deep \"work\"").lua
        #expect(KeybindingCatalog.switchTarget(of: lua) == "deep \"work\"")
        #expect(
            KeybindingCatalog.switchTarget(
                of: "KiwiDesk.focus_space(\"1\")"
            ) == nil
        )
        #expect(
            KeybindingCatalog.switchTarget(
                of: "KiwiDesk.switch_layer(name)"
            ) == nil
        )
        // A raw control character parses but is not what the
        // catalog writes, so the drawn row would not address it.
        #expect(
            KeybindingCatalog.switchTarget(
                of: "KiwiDesk.switch_layer(\"a\tb\")"
            ) == nil
        )
    }

    /// A switch row to a layer no longer listed is drawn where it can
    /// be removed — the Inactive group, the panel and the reset all
    /// ask `OrphanedShortcuts` with the layer list (#820's one
    /// question), and listed never pruned: `init.lua` may define it.
    @Test("a switch to an absent layer is an inactive row")
    @MainActor
    func absentLayerSwitchIsInactive() {
        let rows = [switchRow("gone"), switchRow("focus"), switchRow("gone")]
        let commands = OrphanedShortcuts.commands(
            bindings: rows,
            spaces: [],
            layers: [KeyLayer.defaultName, "focus"]
        )
        #expect(
            commands.map(\.lua)
                == [KeybindingCatalog.switchLayerCommand("gone").lua]
        )
        #expect(
            OrphanedShortcuts.commands(bindings: rows, spaces: []).isEmpty
        )
    }

    @Test("the Inactive group captions what it lists")
    @MainActor
    func captionsFollowTheRows() {
        let gone = KeybindingCatalog.switchLayerCommand("gone")
        let space = OrphanedShortcuts.perSpaceCommands(
            for: SpaceID("9"),
            icons: [:]
        )[0]
        let only = OrphanedShortcuts.captions(for: [gone])
        #expect(!only.spaces && only.layers)
        let none = OrphanedShortcuts.captions(for: [space])
        #expect(none.spaces && !none.layers)
        let both = OrphanedShortcuts.captions(for: [space, gone])
        #expect(both.spaces && both.layers)
    }

    @Test("every inactive surface hands over its layers")
    func surfacesPassTheirLayers() throws {
        let root = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk")
        var calls = 0
        var withLayers = 0
        for file in try SourceScan.swiftSources(under: root) {
            let source = try SourceScan.strippedSource(at: file)
            let parts = source.components(
                separatedBy: "OrphanedShortcuts.commands("
            )
            for part in parts.dropFirst() {
                calls += 1
                let args = part.prefix(while: { $0 != ")" })
                if args.contains("layers:") { withLayers += 1 }
            }
        }
        #expect(calls == 3)
        #expect(withLayers == calls)
        // And each hands over the layers it shows, never a stand-in.
        let values = [
            "Settings/Sections/ShortcutsSection.swift":
                "layers: model.config.layers.map(\\.name)",
            "Settings/Components/Keybindings/OrphanedShortcutsGroup.swift":
                "layers: layers,",
            "Settings/SettingsModel+Reset.swift":
                "layers: config.layers.map(\\.name)",
            "Shortcuts/ShortcutsReference.swift": "layers: layerNames,",
            "Shortcuts/ShortcutsReference+Bands.swift": "layers: layers,",
        ]
        for (path, needle) in values {
            let source = try SourceScan.strippedSource(
                at: root.appendingPathComponent(path)
            )
            #expect(
                source.components(separatedBy: needle).count == 2,
                "\(path)"
            )
        }
    }
}
