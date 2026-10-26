import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts offers that Settings' retired Simple / Power User
/// toggle once withheld (#2654): Layers, Modifier keys and Lua
/// bindings are collapsible cards, shut until the config uses
/// them and then open on arrival. Each reads its own hold-open,
/// and none swaps its container for another once in use — a
/// recorder inside must survive its first combo (#1125).
///
/// **The half that must never break**: a user's own layers,
/// modifier keys or Lua bindings are never folded away on
/// arrival. Layers shipped that defect once, by reading its rows
/// as `.showMore`.
@MainActor
@Suite("Shortcuts offer disclosures (#2654)")
struct ShortcutsOfferDisclosureTests {
    private func config(layers: [String]) -> GuiConfig {
        var config = GuiConfig()
        config.layers = layers.map { KeyLayer(name: $0) }
        return config
    }

    @Test("Lua bindings hold open on a custom binding alone")
    func luaBindingsHoldOpen() {
        var config = config(layers: ["default"])
        #expect(!ShortcutsGates(config: config).luaBindingsExist)
        config.layers[0].bindings.append(KeyBinding(kind: .custom))
        #expect(ShortcutsGates(config: config).luaBindingsExist)
    }

    @Test("Modifier keys hold open on any of their three uses")
    func modifierKeysHoldOpen() {
        #expect(
            !ShortcutsGates.modifierKeysInUse(
                key: nil,
                usesHyper: false,
                keepsSides: false
            )
        )
        #expect(
            ShortcutsGates.modifierKeysInUse(
                key: .capsLock,
                usesHyper: false,
                keepsSides: false
            )
        )
        #expect(
            ShortcutsGates.modifierKeysInUse(
                key: nil,
                usesHyper: true,
                keepsSides: false
            )
        )
        #expect(
            ShortcutsGates.modifierKeysInUse(
                key: nil,
                usesHyper: false,
                keepsSides: true
            )
        )
    }

    /// Each card opens on arrival from its own reading and never
    /// shuts itself — read at the call site, since a predicate
    /// nothing consults would pass the test above.
    @Test("each card opens on arrival from its own hold-open")
    func cardsOpenOnArrival() throws {
        #expect(
            try squashed("Sections/LayersCard.swift").contains(
                ".onAppear{iflayersExist{expanded=true}}"
            )
        )
        let modifier = try squashed(
            "Components/Keybindings/ModifierKeysCard.swift"
        )
        #expect(modifier.contains(".onAppear{ifinUse{expanded=true}}"))
        #expect(modifier.contains("ShortcutsGates.modifierKeysInUse("))
        #expect(
            try squashed("Sections/ShortcutsSection.swift").contains(
                ".onAppear{ifShortcutsGates(config:model.config)"
                    + ".luaBindingsExist{advancedExpanded=true}}"
            )
        )
    }

    /// Asked of the declaration's type rather than its source:
    /// a card the collapsible shape draws must be a drawer.
    @Test("Layers and Modifier keys are declared as drawers")
    func declaredAsDrawers() {
        let layers: Any = SettingsCatalog.shortcuts.layersCard
        let modifier: Any = SettingsCatalog.shortcuts.modifierKeys
        #expect(layers is AnySettingsDrawer)
        #expect(modifier is AnySettingsDrawer)
    }

    private func squashed(_ path: String) throws -> String {
        let url = SourceScan.repoRoot(from: #filePath)
            .appendingPathComponent("Sources/KiwiDesk/Settings")
            .appendingPathComponent(path)
        let raw = try String(contentsOf: url, encoding: .utf8)
        #expect(!raw.isEmpty)
        return SourceScan.stripComments(raw)
            .split(whereSeparator: \.isWhitespace)
            .joined()
    }
}
