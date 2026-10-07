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

    /// The strip's Delete button takes the catalog's delete, or the
    /// rows survive the layer again.
    @Test("the strip deletes through the catalog")
    func stripTakesTheCatalogDelete() throws {
        let file = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent(
                "Sources/KiwiDesk/Settings/Sections/LayerStripEditor.swift"
            )
        let source = try SourceScan.strippedSource(at: file)
        let count = { (needle: String) in
            source.components(separatedBy: needle).count - 1
        }
        #expect(count("KeybindingCatalog.deleteLayer(") == 1)
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
    }

    /// A switch row to a layer no longer listed is drawn where it can
    /// be removed — the Inactive group, the panel and the reset all
    /// ask `OrphanedShortcuts` with the layer list (#820's one
    /// question), and listed never pruned: `init.lua` may define it.
    @Test("a switch to an absent layer is an inactive row")
    @MainActor
    func absentLayerSwitchIsInactive() {
        let rows = [switchRow("gone"), switchRow("focus")]
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
    }
}
