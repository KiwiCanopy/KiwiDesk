import Foundation
import Testing

@testable import KiwiDeskCore

/// One invariant (#1393): every change the key table takes, once
/// encoded to files, reads back through the override resolution as
/// the table said — so no path can leave a profile resolving what
/// the checklist showed away.
@Suite("Rule reach, shortcut round trip (#1393)")
struct RuleReachKeyRoundTripTests {
    private let terminal = "open_or_focus('com.apple.Terminal')"
    private let finder = "open_or_focus('com.apple.finder')"
    private let reload = "KiwiDesk.reload_config()"

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .application, label: lua)
    }

    private var base: [KeyLayer] {
        [
            KeyLayer(
                name: "default",
                bindings: [row("ctrl+alt+t", terminal), row("alt+r", reload)]
            )
        ]
    }

    private var overrides: [(profile: String, override: KeyLayerOverride?)] {
        [
            ("Work", nil),
            (
                "Home",
                KeyLayerOverride(layers: [
                    KeyLayer(
                        name: "default",
                        bindings: [row("ctrl+alt+y", finder)]
                    )
                ])
            ),
            (
                "Travel",
                KeyLayerOverride(layers: [
                    KeyLayer(
                        name: "default",
                        bindings: [row("ctrl+alt+t", finder)]
                    )
                ])
            ),
        ]
    }

    private func key(_ lua: String) -> String {
        RuleReachTable<String>.keyID(layer: "default", lua: lua)
    }

    /// Encodes `t`, then reads the files back as a fresh table.
    private func roundTrip(_ t: RuleReachTable<String>) -> RuleReachTable<
        String
    > {
        var templates: [String: KeyBinding] = [:]
        RuleReachTable<String>.collectTemplates(base, into: &templates)
        for (_, over) in overrides {
            RuleReachTable<String>.collectTemplates(
                over?.resolved(onto: base) ?? base,
                into: &templates
            )
        }
        let newBase = t.keyLayerBase(original: base, templates: templates)
        return .keyLayers(
            base: newBase,
            overrides: overrides.map { name, original in
                (
                    name,
                    t.keyLayerOverride(
                        for: name,
                        original: original,
                        newBase: newBase,
                        templates: templates
                    )
                )
            }
        )
    }

    private func expectSame(_ t: RuleReachTable<String>, _ label: String) {
        let back = roundTrip(t)
        for profile in t.profiles {
            #expect(
                back.resolved(for: profile).filter { !$0.value.isEmpty }
                    == t.resolved(for: profile).compactMapValues { $0 }
                    .filter { !$0.value.isEmpty },
                Comment(
                    rawValue: "\(label): \(profile) reads back differently"
                )
            )
        }
    }

    @Test("Every change reads back as the table said")
    func everyChangeRoundTrips() {
        var shared = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        shared.applyKey(
            key(terminal),
            value: "ctrl+alt+y",
            reach: .shared(joining: []),
            editing: "Work"
        )
        expectSame(shared, "shared move over a follower's own row")

        var here = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        here.applyKey(
            key(reload),
            value: nil,
            reach: .shared(joining: []),
            removal: .here,
            editing: "Work"
        )
        expectSame(here, "remove here leaves out")

        var moved = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        moved.applyKey(
            key(terminal),
            value: "ctrl+alt+u",
            reach: .listed(["Work"]),
            editing: "Work"
        )
        expectSame(moved, "listed to one profile")

        var everywhere = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        everywhere.applyKey(
            key(reload),
            value: nil,
            reach: .shared(joining: []),
            removal: .everywhere,
            editing: "Work"
        )
        expectSame(everywhere, "remove everywhere")

        var ticked = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        ticked.applyKey(
            key(terminal),
            value: "ctrl+alt+t",
            reach: .shared(joining: ["Travel"]),
            editing: "Work"
        )
        expectSame(ticked, "tick takes the key over")

        var listed = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: overrides
        )
        listed.applyKey(
            key(reload),
            value: "alt+r",
            reach: .listed(["Work", "Home"]),
            editing: "Work"
        )
        expectSame(listed, "shared turned into a list")
    }

    /// `sameShortcuts` decides whether gui.json is written and hotkeys
    /// re-register; a field added to either type must be ruled into
    /// what it compares or what it ignores.
    @Test("sameShortcuts rules on every stored field")
    func sameShortcutsFieldParity() {
        let binding = Set(
            Mirror(reflecting: KeyBinding()).children.compactMap(\.label)
        )
        #expect(binding == ["id", "combo", "lua", "kind", "label"])
        let layer = Set(
            Mirror(reflecting: KeyLayer(name: "x")).children.compactMap(
                \.label
            )
        )
        #expect(layer == ["name", "icon", "bindings"])
    }
}
