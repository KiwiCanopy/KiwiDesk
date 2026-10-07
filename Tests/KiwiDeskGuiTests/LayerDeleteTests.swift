import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// #2016: deleting a layer deletes every row that switches to it —
/// such a row does nothing, and no Settings row is drawn to remove
/// it by. Only that name goes: a switch row to a layer `init.lua`
/// defines reads as dangling to the GUI config.
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
        #expect(count("layers.removeAll") == 0)
    }
}
