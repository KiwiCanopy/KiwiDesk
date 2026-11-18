import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// An app's Pocket key row in the GUI (#2612 ▸ 6): Settings writes
/// exactly `PocketAppLuaArg.call`, kind `navigation`; an imported
/// row of that shape is recognised as one; KiwiHub lists it as
/// "Pocket ‹app›" right under the Pocket's own keys (#3449), and the
/// naming door names it the same way.
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

    @Test("KiwiHub lists the key under the Pocket's own, with its icon")
    func hubRowFollowsThePocketKeys() {
        LocalizationManager.shared.select("en")
        var pocket = KeybindingCatalog.pocketAppBinding(app)
        pocket.combo = "control+option+t"
        var early = KeybindingCatalog.pocketAppBinding("a.early")
        early.combo = "control+option+y"
        let open = KeyBinding(
            combo: "control+option+g",
            lua: KeybindingCatalog.appCommand(app),
            kind: .application,
            label: app
        )
        let float = KeyBinding(
            combo: "control+option+f",
            lua: KeybindingCatalog.toggleFloating.lua,
            kind: .navigation
        )
        let reference = hub(
            [pocket, open, float] + pocketKeys() + [early]
        )
        #expect(reference.apps.map(\.label) == [app])
        let band = reference.controls.first { $0.group == .sizeFloat }
        let ids = band?.rows.map(\.id) ?? []
        let last = KeybindingCatalog.pocketWindow.lua
        guard let mark = ids.firstIndex(of: last) else {
            Issue.record("the Pocket rows are not in Size & float")
            return
        }
        // Sorted by app name, right under the last Pocket row.
        let after = band?.rows.dropFirst(mark + 1).prefix(2)
        #expect(after?.map(\.label) == ["Pocket a.early", "Pocket \(app)"])
        #expect(after?.last?.bundleID == app)
        #expect(reference.custom.isEmpty)
    }

    @Test("the key follows Pocket rows a binding files elsewhere")
    func hubRowFollowsRegroupedPocketKeys() {
        LocalizationManager.shared.select("en")
        var pocket = KeybindingCatalog.pocketAppBinding(app)
        pocket.combo = "control+option+t"
        let keys = pocketKeys().map {
            var key = $0
            key.group = "Mine"
            return key
        }
        // A row filed into the same group from a later band, so
        // "after the last Pocket row" is not the group's foot.
        let bar = KeyBinding(
            combo: "control+option+b",
            lua: KeybindingCatalog.toggleSpaceBar.lua,
            kind: .navigation,
            group: "Mine"
        )
        let reference = hub(keys + [bar, pocket])
        let mine = reference.groups.first { $0.title == "Mine" }
        #expect(
            mine?.rows.map(\.id) == [
                KeybindingCatalog.pocket.lua,
                KeybindingCatalog.pocketWindow.lua,
                pocket.id.uuidString,
                KeybindingCatalog.toggleSpaceBar.lua,
            ]
        )
        let band = reference.controls.first { $0.group == .sizeFloat }
        #expect(band?.rows.contains { $0.bundleID == app } != true)
    }

    @Test("the key lands under the last Pocket row, not the foot")
    func filingTakesThePocketRowsSlot() {
        func row(_ id: String, pocket: Bool = false) -> ShortcutRow {
            var row = ShortcutRow(id: id, label: id, combo: "")
            row.pocketMark = pocket
            return row
        }
        var controls = [
            ShortcutSubgroup(
                title: "Size",
                rows: [row("a"), row("p", pocket: true), row("b")],
                group: .sizeFloat
            )
        ]
        var regrouped: [ShortcutsReferenceBuilder.OwnRow] = []
        ShortcutsReferenceBuilder.filingPocketApps(
            [row("app")],
            controls: &controls,
            regrouped: &regrouped
        )
        #expect(controls[0].rows.map(\.id) == ["a", "p", "app", "b"])
        #expect(regrouped.isEmpty)
    }

    /// ⌃⌥P and ⌃⌥⇧P, in the catalog's order.
    private func pocketKeys() -> [KeyBinding] {
        [
            KeyBinding(
                combo: "control+option+p",
                lua: KeybindingCatalog.pocket.lua,
                kind: .navigation
            ),
            KeyBinding(
                combo: "control+option+shift+p",
                lua: KeybindingCatalog.pocketWindow.lua,
                kind: .navigation
            ),
        ]
    }

    private func hub(_ bindings: [KeyBinding]) -> ShortcutsReference {
        ShortcutsReferenceBuilder.build(
            layer: KeyLayer(name: KeyLayer.defaultName, bindings: bindings),
            spaces: [],
            spaceIcons: [:],
            desktops: [],
            resizeStep: 50,
            layerNames: [KeyLayer.defaultName]
        )
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
