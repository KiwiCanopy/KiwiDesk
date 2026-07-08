import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// Pins `KeybindingCatalog.renameMode` — the pure core of the
/// Shortcuts header's mode rename: the mode itself and every
/// switch-mode row targeting it rewrite together, through the
/// same catalog authority the import classifier matches (#4).
@Suite("Mode rename")
struct ModeRenameTests {
    private func switchRow(_ name: String) -> KeyBinding {
        let cmd = KeybindingCatalog.switchModeCommand(name)
        return KeyBinding(
            combo: "alt+m",
            lua: cmd.lua,
            kind: .navigation,
            label: cmd.label
        )
    }

    @Test("renames the mode and rewrites switch rows")
    func renameRewritesRows() {
        var focus = KeyMode(name: "focus")
        focus.bindings = [switchRow("default")]
        var base = KeyMode(name: KeyMode.defaultName)
        base.bindings = [
            switchRow("focus"),
            KeyBinding(
                combo: "alt+h",
                lua: "KiwiDesk.focus(\"left\")",
                kind: .custom,
                label: "left"
            ),
        ]
        let renamed = KeybindingCatalog.renameMode(
            in: [base, focus],
            from: "focus",
            to: "deep work"
        )
        #expect(renamed[1].name == "deep work")
        let expected =
            KeybindingCatalog.switchModeCommand("deep work")
        #expect(renamed[0].bindings[0].lua == expected.lua)
        #expect(
            renamed[0].bindings[0].label == expected.label
        )
        // Non-switch rows and rows targeting other modes
        // pass through untouched.
        #expect(
            renamed[0].bindings[1].lua
                == "KiwiDesk.focus(\"left\")"
        )
        let unchanged =
            KeybindingCatalog.switchModeCommand("default")
        #expect(renamed[1].bindings[0].lua == unchanged.lua)
    }

    @Test("renaming an absent mode changes nothing")
    func absentModeIsNoOp() {
        var base = KeyMode(name: KeyMode.defaultName)
        base.bindings = [switchRow("focus")]
        let out = KeybindingCatalog.renameMode(
            in: [base],
            from: "ghost",
            to: "phantom"
        )
        #expect(out == [base])
    }
}
