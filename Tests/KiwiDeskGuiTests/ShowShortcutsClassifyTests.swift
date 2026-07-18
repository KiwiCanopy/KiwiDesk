import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A recovered `KiwiDesk.show_shortcuts()` binding must classify
/// as navigation with its catalog label, not demote to Custom
/// (#330) — the catalog, the classifier, and the Core verb all
/// speak of one Lua body.
@Suite("show_shortcuts import classification")
@MainActor
struct ShowShortcutsClassifyTests {
    @Test("A show_shortcuts row upgrades out of Custom")
    func classifies() {
        var config = GuiConfig()
        config.modes = [
            KeyMode(
                name: KeyMode.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+space",
                        lua: ShortcutsOpenBinding.lua,
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.modes[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Show shortcuts panel")
    }

    @Test("The catalog row and the Core verb share one Lua body")
    func luaMatchesCoreVerb() {
        #expect(
            ShortcutsOpenBinding.lua == "KiwiDesk.show_shortcuts()"
        )
        #expect(
            KeybindingCatalog.showShortcuts.lua
                == ShortcutsOpenBinding.lua
        )
    }
}
