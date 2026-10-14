import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A recovered `kiwihub.show("shortcuts")` binding must classify
/// as navigation with its catalog label, not demote to Custom
/// (#330) — the catalog, the classifier, and the Core verb all
/// speak of one Lua body.
@Suite("Shortcuts-side import classification")
@MainActor
struct ShowShortcutsClassifyTests {
    @Test("A shortcuts-side row upgrades out of Custom")
    func classifies() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
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
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Show shortcuts panel")
    }

    @Test("The catalog row and the Core verb share one Lua body")
    func luaMatchesCoreVerb() {
        #expect(
            ShortcutsOpenBinding.lua == KiwiHubSide.shortcuts.lua
        )
        #expect(
            KeybindingCatalog.showShortcuts.lua
                == ShortcutsOpenBinding.lua
        )
    }
}
