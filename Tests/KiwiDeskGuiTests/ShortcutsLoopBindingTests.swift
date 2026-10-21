import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A loop-built `init.lua` Space binding, as the capture spells it,
/// lands on its catalog row rather than in Custom (#2485).
@Suite("Shortcuts panel: loop-built Space rows")
@MainActor
struct ShortcutsLoopBindingTests {
    @Test("A captured bare-number Space call is a Go to Space row")
    func loopRowIsNamed() throws {
        let lua = SpaceLuaArg.catalogSpelling(
            of: "KiwiDesk.focus_space(3)"
        )
        let layer = KeyLayer(
            name: KeyLayer.defaultName,
            bindings: [
                KeyBinding(combo: "control+option+3", lua: lua)
            ]
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: layer,
            spaces: ["1", "2", "3"],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.custom.isEmpty)
        let rows = reference.controls.flatMap(\.rows)
        #expect(rows.map(\.id) == [lua])
    }
}
