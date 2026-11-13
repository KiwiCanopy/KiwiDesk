import Foundation
import KiwiDeskCore
import Testing

@testable import KiwiDesk

/// The Shortcuts offers that Settings' retired Simple / Power User
/// toggle once withheld (#2654): Layers, Modifier keys and Lua
/// bindings are collapsible cards, shut until the config uses
/// them and then open on arrival — save Modifier keys, a drawer of
/// settings, which opens only in trouble (#3261). Each reads its
/// own hold-open, and none swaps its container for another once in use — a
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

    @Test("Lua bindings hold open on the selected layer's own")
    func luaBindingsHoldOpen() {
        var config = config(layers: ["default", "work"])
        // A built-in row is not a Lua binding: the kind decides.
        config.layers[0].bindings.append(KeyBinding(kind: .navigation))
        config.layers[1].bindings.append(KeyBinding(kind: .application))
        #expect(
            !ShortcutsGates(config: config).luaBindingsExist(in: "work")
        )
        config.layers[1].bindings.append(KeyBinding(kind: .custom))
        let gates = ShortcutsGates(config: config)
        #expect(gates.luaBindingsExist(in: "work"))
        // Per layer: the drawer lists the selected layer alone.
        #expect(!gates.luaBindingsExist(in: "default"))
    }

    /// Modifier keys is a drawer of settings (#3261): shut on
    /// arrival whatever is set, open only while the remap is refused
    /// with a Take Over to offer.
    @Test("Modifier keys opens on arrival in trouble alone")
    func modifierKeysOpenInTrouble() {
        let offer = HyperForeignRemap(
            source: .capsLock,
            destination: .f18,
            claimable: true
        )
        let open = { (status: HyperKeyStatus, lua: Bool) in
            ModifierKeysCard.opensOnArrival(status: status, luaOwned: lua)
        }
        #expect(open(.refused(offer), false))
        #expect(!open(.refused(offer), true))
        #expect(!open(.on, false))
        #expect(!open(.off, false))
        #expect(!open(.refused(nil), false))
        let unclaimable = HyperForeignRemap(
            source: .capsLock,
            destination: .f18
        )
        #expect(!open(.refused(unclaimable), false))
    }

    /// The shut summary states what is set, by the rows' titles,
    /// and speaks ✦ in words (#3261).
    @Test("the shut summary states the values set")
    func modifierKeysSummary() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let summary = {
            (
                key: HyperSourceKey?,
                base: ShortcutBase,
                sides: Bool,
                spoken: Bool
            ) in
            ModifierKeysCard.summary(
                key: key,
                working: true,
                base: base,
                sides: sides,
                spoken: spoken
            )
        }
        #expect(
            summary(nil, .standard, false, false)
                == ModifierKeysCard.description
        )
        #expect(
            summary(.capsLock, .hyper, false, false)
                == "Hyper: Caps Lock · Shortcuts use ✦"
        )
        let spoken = summary(.capsLock, .hyper, true, true)
        #expect(!spoken.contains("✦"))
        #expect(
            spoken
                == "Hyper: Caps Lock · Shortcuts use "
                + ShortcutBaseWords.spoken(.hyper, keySet: true)
                + " · " + ModifierSidesWords.title
        )
        #expect(
            summary(nil, .standard, true, false)
                == ModifierSidesWords.title
        )
        // A Hyper key not in effect says so, shut (#3261).
        #expect(
            ModifierKeysCard.summary(
                key: .capsLock,
                working: false,
                base: .standard,
                sides: false,
                spoken: false
            ) == "Hyper: Caps Lock, not working"
        )
        #expect(ModifierKeysCard.hyperWorks(.on))
        #expect(!ModifierKeysCard.hyperWorks(.off))
        #expect(!ModifierKeysCard.hyperWorks(.failed))
        #expect(!ModifierKeysCard.hyperWorks(.refused(nil)))
    }

    /// Each card opens on arrival from its own reading and never
    /// shuts itself — read at the call site, since a predicate
    /// nothing consults would pass the test above.
    @Test("each card opens on arrival from its own hold-open")
    func cardsOpenOnArrival() throws {
        let layers = try squashed("Sections/LayersCard.swift")
        #expect(layers.contains(".onAppear{iflayersExist{expanded=true}}"))
        #expect(
            layers.contains("ShortcutsGates(config:model.config).layersExist")
        )
        let modifier = try squashed(
            "Components/Keybindings/ModifierKeysCard.swift"
        )
        #expect(modifier.contains(".onAppear{iftroubled{expanded=true}}"))
        #expect(modifier.contains("Self.opensOnArrival("))
        let summary = try squashed(
            "Components/Keybindings/ModifierKeysCard+Summary.swift"
        )
        #expect(
            summary.contains("working:Self.hyperWorks(model.hyperStatus)")
        )
        // The summary and its spoken twin reach the drawer.
        #expect(
            modifier.contains(
                "summary:summary(spoken:false),"
                    + "spokenSummary:summary(spoken:true)"
            )
        )
        let section = try squashed(
            "Components/Common/SettingsCollapsibleSection.swift"
        )
        #expect(
            section.contains(".accessibilityLabel(spokenSummary??summary)")
        )
        #expect(
            try squashed("Sections/ShortcutsSection.swift").contains(
                ".onAppear{letgates=ShortcutsGates(config:model.config)"
                    + "ifgates.luaBindingsExist(in:selected)"
                    + "{advancedExpanded=true}}"
            )
        )
    }

    /// The drawer's rows and its hold-open read one predicate, so
    /// an imported kind cannot be listed with the drawer shut.
    @Test("Lua rows and the hold-open share one predicate")
    func luaPredicateIsShared() throws {
        #expect(
            try squashed("Components/Lua/AdvancedLuaGroup.swift")
                .contains("ifShortcutsGates.isLuaBinding(binding){")
        )
        #expect(
            try squashed("Components/Keybindings/ShortcutsGates.swift")
                .contains(".contains(where:Self.isLuaBinding)")
        )
    }

    /// A hit on a layer's static-label row opens the Layers card
    /// even after the user shut it (#1250's obligation, #2654).
    @Test("a layer row's search hit opens the Layers card")
    func layerRowHitsOpenTheCard() {
        LocalizationManager.shared.select("en")
        defer { LocalizationManager.shared.select(nil) }
        let rows = SettingsSearchIndex.rows()
        let card = SettingsCatalog.shortcuts.layersCard
        for key in [
            SettingKey.shortcuts(.layersIcon), .shortcuts(.layersReach),
        ] {
            let anchor = rows.first { $0.key == key }?.anchor.anchor
            #expect(anchor != nil, Comment(rawValue: key.id))
            #expect(
                card.shouldExpand(revealing: anchor),
                Comment(rawValue: key.id)
            )
        }
    }

    /// The search index anchors a hit from the catalog join alone,
    /// so the view's own anchor is pinned at its call site — a
    /// deleted `.searchAnchored` opens the card onto nothing.
    @Test("each card row a hit lands on carries its anchor")
    func rowsCarryTheirAnchors() throws {
        let header = try squashed("Sections/LayerHeader.swift")
        for row in ["reach", "menuBarIcon"] {
            #expect(
                header.contains(
                    ".searchAnchored(SettingsCatalog.shortcuts"
                        + ".layersCard.children.\(row))"
                ),
                Comment(rawValue: row)
            )
        }
        let card = try squashed(
            "Components/Keybindings/ModifierKeysCard.swift"
        )
        for row in ["hyperKey", "shortcutBase"] {
            #expect(
                card.contains(
                    ".searchAnchored(SettingsCatalog.shortcuts"
                        + ".modifierKeys.children.\(row))"
                ),
                Comment(rawValue: row)
            )
        }
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
