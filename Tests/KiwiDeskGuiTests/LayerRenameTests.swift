import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Pins `KeybindingCatalog.renameLayer` — the pure core of the
/// Shortcuts header's layer rename: the layer itself and every
/// switch-layer row targeting it rewrite together, through the
/// same catalog authority the import classifier matches (#4).
@Suite("Mode rename")
struct ModeRenameTests {
    private func switchRow(_ name: String) -> KeyBinding {
        let cmd = KeybindingCatalog.switchLayerCommand(name)
        return KeyBinding(
            combo: "alt+m",
            lua: cmd.lua,
            kind: .navigation,
            label: cmd.label
        )
    }

    @Test("renames the layer and rewrites switch rows")
    func renameRewritesRows() {
        var focus = KeyLayer(name: "focus")
        focus.bindings = [switchRow("default")]
        var base = KeyLayer(name: KeyLayer.defaultName)
        base.bindings = [
            switchRow("focus"),
            KeyBinding(
                combo: "alt+h",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .custom,
                label: "left"
            ),
        ]
        let renamed = KeybindingCatalog.renameLayer(
            in: [base, focus],
            from: "focus",
            to: "deep work"
        )
        #expect(renamed[1].name == "deep work")
        let expected =
            KeybindingCatalog.switchLayerCommand("deep work")
        #expect(renamed[0].bindings[0].lua == expected.lua)
        #expect(
            renamed[0].bindings[0].label == expected.label
        )
        // Non-switch rows and rows targeting other layers
        // pass through untouched.
        #expect(
            renamed[0].bindings[1].lua
                == "KiwiDesk.focus(\"left\")"
        )
        let unchanged =
            KeybindingCatalog.switchLayerCommand("default")
        #expect(renamed[1].bindings[0].lua == unchanged.lua)
    }

    @Test("the default layer can never be renamed")
    func defaultLayerIsAnchored() {
        var base = KeyLayer(name: KeyLayer.defaultName)
        base.bindings = [switchRow(KeyLayer.defaultName)]
        let out = KeybindingCatalog.renameLayer(
            in: [base],
            from: KeyLayer.defaultName,
            to: "base"
        )
        #expect(out == [base])
    }

    @Test("renaming an absent layer changes nothing")
    func absentModeIsNoOp() {
        var base = KeyLayer(name: KeyLayer.defaultName)
        base.bindings = [switchRow("focus")]
        let out = KeybindingCatalog.renameLayer(
            in: [base],
            from: "ghost",
            to: "phantom"
        )
        #expect(out == [base])
    }
}
