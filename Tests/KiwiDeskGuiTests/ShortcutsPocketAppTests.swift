import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// An app's Pocket key row in the GUI (#2612 ▸ 6): Settings writes
/// exactly `PocketAppLuaArg.call`, kind `navigation`; an imported
/// row of that shape is recognised as one; KiwiHub lists it as
/// "Pocket ‹app›" right after that app's own key, and the naming
/// door names it the same way.
@Suite("Shortcuts ▸ per-app Pocket key", .serialized)
@MainActor
struct ShortcutsPocketAppTests {
    /// No installed app answers this id, so its name is the id.
    private let app = "org.kiwidesk.pocket-test"

    @Test("a new row writes the exact call, kind navigation")
    func newRowShape() {
        let binding = KeybindingCatalog.pocketAppBinding(
            "Org.KiwiDesk.Pocket-Test"
        )
        #expect(binding.lua == PocketAppLuaArg.call(app))
        #expect(binding.lua == "KiwiDesk.pocket_app(\"\(app)\")")
        #expect(binding.kind == .navigation)
        #expect(binding.combo.isEmpty)
    }

    @Test("an imported row of that shape is a navigation row")
    func importClassifies() {
        LocalizationManager.shared.select("en")
        var config = GuiConfig()
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [
                    KeyBinding(
                        combo: "control+option+t",
                        lua: PocketAppLuaArg.call(app),
                        kind: .custom
                    )
                ]
            )
        ]
        KeybindingImportClassifier.classify(&config)
        let row = config.layers[0].bindings[0]
        #expect(row.kind == .navigation)
        #expect(row.label == "Pocket \(app)")
        #expect(
            KeybindingCatalog.localizedName(of: row, config: config)
                == "Pocket \(app)"
        )
    }

    @Test("the naming door names an unlabelled row by its shape")
    func doorNamesAnUnlabelledRow() {
        LocalizationManager.shared.select("en")
        let row = KeyBinding(
            combo: "control+option+t",
            lua: PocketAppLuaArg.call(app),
            kind: .navigation
        )
        var config = GuiConfig()
        config.layers = [
            KeyLayer(name: KeyLayer.defaultName, bindings: [row])
        ]
        #expect(
            KeybindingCatalog.localizedName(of: row, config: config)
                == "Pocket \(app)"
        )
    }

    @Test("pocketApps reads each app once, in binding order")
    func pocketAppsOrder() {
        let bindings = [
            KeybindingCatalog.pocketAppBinding("b.app"),
            KeyBinding(
                combo: "",
                lua: "KiwiDesk.pocket()",
                kind: .navigation
            ),
            KeybindingCatalog.pocketAppBinding("a.app"),
            KeybindingCatalog.pocketAppBinding("B.App"),
            KeyBinding(
                combo: "",
                lua: "KiwiDesk.pocket_app(\"C.App\")",
                kind: .custom
            ),
        ]
        #expect(
            KeybindingCatalog.pocketApps(in: bindings)
                == ["b.app", "a.app", "c.app"]
        )
    }

    @Test("KiwiHub lists the key after the app's own, with its icon")
    func hubRowFollowsTheAppsKey() {
        LocalizationManager.shared.select("en")
        var pocket = KeybindingCatalog.pocketAppBinding(app)
        pocket.combo = "control+option+t"
        let open = KeyBinding(
            combo: "control+option+g",
            lua: KeybindingCatalog.appCommand(app),
            kind: .application,
            label: app
        )
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [pocket, open]
            ),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        let labels = reference.apps.map(\.label)
        #expect(labels == [app, "Pocket \(app)"])
        #expect(reference.apps.last?.bundleID == app)
        #expect(reference.custom.isEmpty)
    }

    @Test("an unbound row stays off KiwiHub")
    func unboundRowIsNotListed() {
        let reference = ShortcutsReferenceBuilder.build(
            layer: KeyLayer(
                name: KeyLayer.defaultName,
                bindings: [KeybindingCatalog.pocketAppBinding(app)]
            ),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
        #expect(reference.apps.isEmpty)
    }
}
