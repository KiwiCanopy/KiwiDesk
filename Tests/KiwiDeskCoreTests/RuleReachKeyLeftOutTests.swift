import Foundation
import Testing

@testable import KiwiDeskCore

/// A shortcut one profile leaves out or moves (#1393): the removed
/// combo on that profile's override, the shared row kept.
@Suite("Rule reach, shortcuts left out (#1393)")
struct RuleReachKeyLeftOutTests {
    private let terminal = "open_or_focus('com.apple.Terminal')"
    private let finder = "open_or_focus('com.apple.finder')"

    private func row(_ combo: String, _ lua: String) -> KeyBinding {
        KeyBinding(combo: combo, lua: lua, kind: .application, label: lua)
    }

    /// The base binds ⌃⌥T to Terminal; Travel rebinds ⌃⌥T to Finder.
    private var base: [KeyLayer] {
        [KeyLayer(name: "default", bindings: [row("ctrl+alt+t", terminal)])]
    }

    private var travel: KeyLayerOverride {
        KeyLayerOverride(layers: [
            KeyLayer(name: "default", bindings: [row("ctrl+alt+t", finder)])
        ])
    }

    private var table: RuleReachTable<String> {
        .keyLayers(
            base: base,
            overrides: [("Work", nil), ("Home", nil), ("Travel", travel)]
        )
    }

    private var key: String {
        RuleReachTable<String>.keyID(layer: "default", lua: terminal)
    }

    private var templates: [String: KeyBinding] {
        var result: [String: KeyBinding] = [:]
        RuleReachTable<String>.collectTemplates(base, into: &result)
        RuleReachTable<String>.collectTemplates(
            travel.resolved(onto: base),
            into: &result
        )
        return result
    }

    @Test("Remove here leaves one profile out of the shared shortcut")
    func removeLeavesOut() {
        var t = table
        t.applyKey(
            key,
            value: nil,
            reach: .shared(joining: []),
            removal: .here,
            editing: "Work"
        )
        #expect(t.base[key] == "ctrl+alt+t")
        #expect(t.resolved(key, for: "Work") == nil)
        #expect(t.follows(key, "Home"))
        #expect(t.leftOut(key) == ["Work", "Travel"])
        #expect(t.touched["Home"] == nil)
    }

    @Test("A left-out shortcut encodes as the override's removed combo")
    func leftOutEncodes() {
        var t = table
        t.applyKey(
            key,
            value: nil,
            reach: .shared(joining: []),
            removal: .here,
            editing: "Work"
        )
        let newBase = t.keyLayerBase(original: base, templates: templates)
        #expect(RuleReachTable<String>.combos(newBase)[key] == "ctrl+alt+t")
        let work = t.keyLayerOverride(
            for: "Work",
            original: nil,
            newBase: newBase,
            templates: templates
        )
        #expect(work?.removed == ["default": ["ctrl+alt+t"]])
        #expect(work?.layers == [])
        let resolved = work?.resolved(onto: newBase) ?? newBase
        #expect(RuleReachTable<String>.combos(resolved)[key] == nil)
    }

    @Test("A profile's own move re-encodes with the removed combo")
    func movedInOneProfile() {
        // Work already moved Terminal off the shared combo.
        let moved = KeyLayerOverride(
            layers: [
                KeyLayer(
                    name: "default",
                    bindings: [row("ctrl+alt+u", terminal)]
                )
            ],
            removed: ["default": ["ctrl+alt+t"]]
        )
        var t = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Work", moved), ("Home", nil)]
        )
        #expect(t.reach(of: key, editing: "Work") == .listed(["Work"]))
        t.applyKey(
            key,
            value: "ctrl+alt+y",
            reach: .listed(["Work"]),
            editing: "Work"
        )
        #expect(t.base[key] == "ctrl+alt+t")
        #expect(t.follows(key, "Home"))
        let newBase = t.keyLayerBase(original: base, templates: templates)
        let work = t.keyLayerOverride(
            for: "Work",
            original: moved,
            newBase: newBase,
            templates: templates
        )
        #expect(work?.removed == ["default": ["ctrl+alt+t"]])
        let resolved = work?.resolved(onto: newBase) ?? newBase
        #expect(resolved[0].bindings.map(\.combo) == ["ctrl+alt+y"])
    }

    @Test("Remove here on the loaded page keeps the shared row")
    func pageRemoveHereKeepsBase() {
        var t = table
        t.applyKey(
            key,
            value: nil,
            reach: .shared(joining: []),
            removal: .here,
            editing: "Work"
        )
        var page = base
        page[0].bindings.removeAll()
        let shared = t.keyLayerBase(
            page: page,
            editing: "Work",
            storedPage: base,
            storedBase: base,
            templates: templates
        )
        #expect(RuleReachTable<String>.combos(shared)[key] == "ctrl+alt+t")
    }

    @Test("A combo the page's profile left out stays in the base")
    func pageLeftOutKeepsBase() {
        let work = KeyLayerOverride(
            layers: [],
            removed: ["default": ["ctrl+alt+t"]]
        )
        let page = work.resolved(onto: base)
        #expect(page[0].bindings.isEmpty)
        let t = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Work", work)]
        )
        let shared = t.keyLayerBase(
            page: page,
            editing: "Work",
            storedPage: page,
            storedBase: base,
            templates: templates
        )
        #expect(RuleReachTable<String>.combos(shared)[key] == "ctrl+alt+t")
    }
}
