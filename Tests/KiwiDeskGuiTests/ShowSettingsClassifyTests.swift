import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// A recovered `KiwiDesk.show_settings()` binding must classify
/// as navigation with its catalog label, not demote to Custom —
/// the catalog row, the classifier map (`stepFreeCommands`) and
/// the Core verb all speak of one Lua body (#678 item 18, the
/// #330 shape).
@Suite("show_settings import classification")
@MainActor
struct ShowSettingsClassifyTests {
    @Test("An open-settings row upgrades out of Custom")
    func classifies() {
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "alt+comma",
                        lua: KeybindingCatalog.openSettings.lua,
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Open Settings")
    }

    @Test("The catalog row and the Core verb share one Lua body")
    func luaMatchesCoreVerb() {
        #expect(
            KeybindingCatalog.openSettings.lua
                == "KiwiDesk.show_settings()"
        )
        #expect(APIReference.luaOnly.contains("show_settings"))
    }
}
