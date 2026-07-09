import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A keybinding authored before the #42 rename uses the long
/// `*_virtual_space` Lua; import classification canonicalizes it
/// so it still lands in its navigation section instead of Custom.
@MainActor
struct SpaceAliasClassifyTests {
    private func customRow(_ lua: String) -> KeyBinding {
        KeyBinding(combo: "alt+1", lua: lua, kind: .custom)
    }

    private func classified(_ lua: String) -> KeyBinding {
        var config = GuiConfig()
        config.spaces = [SpaceID("1")]
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: [customRow(lua)]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        return config.modes[0].bindings[0]
    }

    @Test("A legacy focus_virtual_space row classifies")
    func legacyFocusClassifies() {
        let row = classified("KiwiDesk.focus_virtual_space(\"1\")")
        #expect(row.kind == .navigation)
        #expect(row.label == "Go to Space 1")
    }

    @Test("A legacy move_to_virtual_space_and_follow classifies")
    func legacyMoveFollowClassifies() {
        let row = classified(
            "KiwiDesk.move_to_virtual_space_and_follow(\"1\")"
        )
        #expect(row.kind == .navigation)
        #expect(row.label == "Move to Space 1 & follow")
    }

    @Test("The short canonical form classifies identically")
    func canonicalClassifies() {
        let row = classified("KiwiDesk.focus_space(\"1\")")
        #expect(row.kind == .navigation)
        #expect(row.label == "Go to Space 1")
    }
}
