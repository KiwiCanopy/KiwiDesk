import Foundation
import Testing

@testable import KiwiDeskCore

/// Shortcuts as a rule-reach table (#1393): one action per layer,
/// read through the override resolution the engine registers and
/// written back through `KeyLayerOverride.diff`, where "not here"
/// is a removed combo, and a written combo takes its key over.
@Suite("Rule reach, shortcuts (#1393)")
struct RuleReachKeyTests {
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

    @Test("A combo another action took reads as left out of the shared one")
    func rebindLeavesOut() {
        let t = table
        #expect(t.reach(of: key, editing: "Work").isShared)
        #expect(t.resolved(key, for: "Travel") == nil)
        #expect(t.leftOut(key) == ["Travel"])
    }

    @Test("Ticking a profile takes its combo over from the other action")
    func tickTakesTheKey() {
        var t = table
        t.applyKey(
            key,
            value: "ctrl+alt+t",
            reach: .shared(joining: ["Travel"]),
            editing: "Work"
        )
        let newBase = t.keyLayerBase(original: base, templates: templates)
        let encoded = t.keyLayerOverride(
            for: "Travel",
            original: travel,
            newBase: newBase,
            templates: templates
        )
        let resolved = encoded?.resolved(onto: newBase) ?? newBase
        let combos = RuleReachTable<String>.combos(resolved)
        #expect(combos[key] == "ctrl+alt+t")
        let finderKey = RuleReachTable<String>.keyID(
            layer: "default",
            lua: finder
        )
        #expect(combos[finderKey] == nil)
    }

    @Test("A page's own layer structure survives into the base")
    func pageStructureKept() {
        var page = base
        page.append(KeyLayer(name: "gaming", icon: "gamecontroller"))
        let shared = table.keyLayerBase(
            page: page,
            editing: "Work",
            storedPage: base,
            storedBase: base,
            templates: templates
        )
        #expect(shared.map(\.name) == ["default", "gaming"])
        #expect(RuleReachTable<String>.combos(shared)[key] == "ctrl+alt+t")
    }

    @Test("A layer only the page's own override carried stays out")
    func ownLayerStaysOut() {
        let work = KeyLayerOverride(layers: [
            KeyLayer(name: "work", bindings: [row("ctrl+alt+w", finder)])
        ])
        let t = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Work", work)]
        )
        let page = work.resolved(onto: base)
        let shared = t.keyLayerBase(
            page: page,
            editing: "Work",
            storedPage: page,
            storedBase: base,
            templates: templates
        )
        #expect(shared.map(\.name) == ["default"])
    }

    @Test("The takeover is recorded in the table, not only the file")
    func takeoverRecorded() {
        var t = table
        t.applyKey(
            key,
            value: "ctrl+alt+t",
            reach: .shared(joining: ["Travel"]),
            editing: "Work"
        )
        let finderKey = RuleReachTable<String>.keyID(
            layer: "default",
            lua: finder
        )
        #expect(t.resolved(finderKey, for: "Travel") == nil)
        #expect(t.touched["Travel"]?.contains(finderKey) == true)
    }

    @Test("A shared combo taken by a new shared action leaves the base")
    func baseTakeover() {
        var t = table
        let reloadKey = RuleReachTable<String>.keyID(
            layer: "default",
            lua: "reload"
        )
        t.applyKey(
            reloadKey,
            value: "ctrl+alt+t",
            reach: .shared(joining: []),
            editing: "Work"
        )
        #expect(t.base[reloadKey] == "ctrl+alt+t")
        #expect(t.base[key] == nil)
    }

    @Test("Removing everywhere over another shared value leaves out")
    func everywhereLeavesOut() {
        // Home moved Terminal to its own combo, spelled the way an
        // override did before it could remove: Finder takes the
        // shared combo and Terminal is bound anew.
        let home = KeyLayerOverride(layers: [
            KeyLayer(
                name: "default",
                bindings: [
                    row("ctrl+alt+t", finder), row("ctrl+alt+y", terminal),
                ]
            )
        ])
        var t = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Work", nil), ("Home", home)]
        )
        #expect(t.resolved(key, for: "Home") == "ctrl+alt+y")
        t.applyKey(
            key,
            value: nil,
            reach: .listed(["Home"]),
            removal: .everywhere,
            editing: "Home"
        )
        #expect(t.base[key] == "ctrl+alt+t")
        #expect(t.follows(key, "Work"))
        #expect(t.resolved(key, for: "Home") == nil)
        #expect(t.leftOut(key) == ["Home"])
    }

    @Test("A combo the page's profile moved never reaches the base")
    func movedComboStaysOut() {
        // Work moved Terminal to ctrl+alt+y the way an override did
        // before it could remove: the shared row stays, its own is
        // appended.
        let work = KeyLayerOverride(layers: [
            KeyLayer(name: "default", bindings: [row("ctrl+alt+y", terminal)])
        ])
        let page = work.resolved(onto: base)
        #expect(page[0].bindings.count == 2)
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
        #expect(shared[0].bindings.map(\.combo) == ["ctrl+alt+t"])
    }

    @Test("A base action bound to two combos keeps both")
    func baseTwoCombosKept() {
        let twice = [
            KeyLayer(
                name: "default",
                bindings: [
                    row("ctrl+alt+t", terminal), row("alt+t", terminal),
                ]
            )
        ]
        let t = RuleReachTable<String>.keyLayers(
            base: twice,
            overrides: [("Work", nil)]
        )
        let shared = t.keyLayerBase(
            page: twice,
            editing: "Work",
            storedPage: twice,
            storedBase: twice,
            templates: templates
        )
        #expect(shared[0].bindings.map(\.combo) == ["ctrl+alt+t", "alt+t"])
        #expect(RuleReachTable<String>.sameShortcuts(shared, twice))
    }

    @Test("A shared move leaves a follower's own row on that combo")
    func followerOwnRowKept() {
        // Home binds ctrl+alt+y to Finder on its own; Work moves the
        // shared Terminal onto ctrl+alt+y. Home did not tick anything.
        let home = KeyLayerOverride(layers: [
            KeyLayer(name: "default", bindings: [row("ctrl+alt+y", finder)])
        ])
        var t = RuleReachTable<String>.keyLayers(
            base: base,
            overrides: [("Work", nil), ("Home", home)]
        )
        t.applyKey(
            key,
            value: "ctrl+alt+y",
            reach: .shared(joining: []),
            editing: "Work"
        )
        let finderKey = RuleReachTable<String>.keyID(
            layer: "default",
            lua: finder
        )
        // Home keeps its own row, which wins on that combo, so it
        // reads as leaving the moved Terminal out — as its file will.
        #expect(t.resolved(finderKey, for: "Home") == "ctrl+alt+y")
        #expect(t.resolved(key, for: "Home") == nil)
    }

    @Test("An edit to a shared action's second combo lands in the base")
    func secondComboEditLands() {
        let twice = [
            KeyLayer(
                name: "default",
                bindings: [
                    row("ctrl+alt+t", terminal), row("alt+t", terminal),
                ]
            )
        ]
        let t = RuleReachTable<String>.keyLayers(
            base: twice,
            overrides: [("Work", nil)]
        )
        var page = twice
        page[0].bindings[1].combo = "alt+shift+t"
        let shared = t.keyLayerBase(
            page: page,
            editing: "Work",
            storedPage: twice,
            storedBase: twice,
            templates: templates
        )
        #expect(
            shared[0].bindings.map(\.combo) == ["ctrl+alt+t", "alt+shift+t"]
        )
    }
}
