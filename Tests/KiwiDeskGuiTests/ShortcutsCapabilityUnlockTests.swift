import Foundation
import Testing

@testable import KiwiDesk
@testable import KiwiDeskCore

@MainActor
private final class UnlockRegistrar: HotkeyRegistrar {
    private var nextID: UInt32 = 1

    func register(
        keyCode: UInt32,
        modifiers: HotkeyModifiers,
        handler: @escaping @MainActor () -> Void
    ) -> UInt32? {
        defer { nextID += 1 }
        return nextID
    }

    func unregister(id: UInt32) {}
}

/// **A used capability unlocks its whole list, and the list is
/// the scope** (#678 decision items 14/15). Two rules the
/// redesign settles now and the mode-mechanics phase inherits:
///
///  - *the whole list.* The moment a profile carries a single
///    shortcut override, the override affordance is live on
///    EVERY row of that list, not only the overridden one. A
///    user who has overridden one key is a user who overrides
///    keys; making them re-discover the affordance per row is
///    the thing this forbids.
///  - *the list, not the app.* Overriding a shortcut must not
///    turn a deeper surface on anywhere else — "the mode becomes
///    something users lose by accident" is the failure. App
///    rules are the nearest neighbour with the same
///    override shape, so they are the probe.
///
/// Both already hold: the affordance keys off *editing a stored
/// profile*, never off a mode or a per-row flag. That is exactly
/// why this suite exists — nothing pinned it, and the cheapest
/// way to implement mode mechanics later is to gate the column
/// on a mode, which would violate both rules at once and break
/// no test.
///
/// Item 15's third clause — the resolver takes no mode input —
/// needs no test because it needs no code: `allowProfileSpecific
/// Shortcuts` was never built, and `KeyLayerOverride.resolved
/// (onto:)` takes a base list and nothing else. A guard against
/// a parameter that does not exist would assert what the type
/// system already says.
@Suite("Shortcuts capability unlock (#678 items 14/15)", .serialized)
@MainActor
struct ShortcutsCapabilityUnlockTests {
    /// Four rows in the base layer, so "the whole list" has
    /// peers to be wrong about — a single-row fixture would pass
    /// this suite while a per-row gate shipped.
    private let baseCombos = [
        ("alt+h", "KiwiDesk.focus(\"left\")"),
        ("alt+l", "KiwiDesk.focus(\"right\")"),
        ("alt+k", "KiwiDesk.focus(\"up\")"),
        ("alt+j", "KiwiDesk.focus(\"down\")"),
    ]

    private func makeModel() throws -> (SettingsModel, KiwiCore) {
        let core = makeTestCore(
            hotkeyRegistrar: UnlockRegistrar()
        )
        var config = GuiConfig()
        // A non-empty app-rules base, so `scopeIsTheListNotTheApp`
        // asserts that the profile does not diverge from a real
        // list. With both sides empty the predicate is false by
        // construction and the test says nothing.
        config.appRules = [
            "com.apple.Safari": "1",
            "com.apple.Terminal": "2",
        ]
        config.layers = [
            KeyLayer(
                name: KeyLayer.defaultName,
                bindings: baseCombos.map {
                    KeyBinding(
                        combo: $0.0,
                        lua: $0.1,
                        kind: .navigation
                    )
                }
            )
        ]
        try core.saveGuiConfig(config)
        return (SettingsModel(core: core), core)
    }

    /// A profile overriding ONE row still resolves a base for
    /// every row of the layer — which is what puts the override
    /// column on the peers. `nil` here would mean "no affordance
    /// on this row", the per-row gate this forbids.
    @Test("one override lights the affordance on every peer")
    func oneOverrideUnlocksTheList() throws {
        let (model, core) = try makeModel()
        var profile = Profile(
            name: "Desk",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: [
                            KeyBinding(
                                combo: "ctrl+alt+h",
                                lua: baseCombos[0].1,
                                kind: .navigation
                            )
                        ]
                    )
                ]
            )
        )
        profile.savedAt = Date(timeIntervalSince1970: 1_780_000_000)
        // `write`, not `save` — saving adopts (#18), and this
        // needs a profile that is not the active one.
        try core.profiles.write(profile)
        model.reload()
        model.selectEditTarget("Desk")
        #expect(model.editingStoredProfile)

        let base = model.overrideBaseRows(layer: KeyLayer.defaultName)
        #expect(base != nil, "editing a profile must expose a base")
        // Every base row is reachable, not just the overridden
        // one — the affordance is the LIST's, not the row's.
        #expect(base?.count == baseCombos.count)
        for (combo, lua) in baseCombos {
            #expect(
                base?.contains { $0.lua == lua && $0.combo == combo }
                    == true,
                Comment(rawValue: "peer \(lua) lost its base row")
            )
        }
    }

    /// Scope is the list. Overriding a shortcut leaves the app
    /// rules list exactly where it was — a capability unlocked in
    /// one list must not read as unlocked app-wide.
    @Test("a shortcut override does not unlock app rules")
    func scopeIsTheListNotTheApp() throws {
        let (model, core) = try makeModel()
        var profile = Profile(
            name: "Desk",
            monitorSets: [MonitorSet(monitors: ["A:100x100"])],
            spaceModes: [:],
            settings: TilingSettings(),
            layers: KeyLayerOverride(
                layers: [
                    KeyLayer(
                        name: KeyLayer.defaultName,
                        bindings: [
                            KeyBinding(
                                combo: "ctrl+alt+h",
                                lua: baseCombos[0].1,
                                kind: .navigation
                            )
                        ]
                    )
                ]
            )
        )
        profile.savedAt = Date(timeIntervalSince1970: 1_780_000_000)
        // `write`, not `save` — saving adopts (#18), and this
        // needs a profile that is not the active one.
        try core.profiles.write(profile)
        model.reload()
        model.selectEditTarget("Desk")
        #expect(model.editingStoredProfile)

        #expect(model.editedProfileOverridesKeys)
        // Vacuity, BOTH sides. `editedProfileOverridesAppRules`
        // short-circuits to false on a missing baseline, so the
        // assertion below is satisfied by the app-rules base
        // being absent as readily as by scoping holding — a
        // fail-open `guard-prover` caught by nilling the
        // baseline and watching this suite stay green. The
        // layers half needs no such pin: its baseline is
        // self-checking, because the line above asserts it TRUE.
        #expect(model.config.appRules.count == 2)
        #expect(model.profileEditingBaseAppRules?.isEmpty == false)
        // The neighbouring list with the same override shape is
        // untouched — the capability stayed in its own list.
        #expect(!model.editedProfileOverridesAppRules)
    }

    /// Nothing in the Shortcuts area is read-only or withheld
    /// because of a mode: mode depth is per AREA and the census
    /// says so with `SettingsArea.minimumMode`. Shortcuts is a
    /// `.simple` area, so every row it places is reachable in
    /// both modes — item 15's "nothing is ever read-only because
    /// of the mode", stated where a Phase 4 change would have to
    /// edit it.
    @Test("Shortcuts is reachable in both modes")
    func shortcutsIsNotModeGated() {
        #expect(SettingsArea.shortcuts.minimumMode == .simple)
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .shortcuts
        }
        #expect(!placed.isEmpty)
        // No row-level mode depth exists to check because the
        // tier enum carries none — assert the tiers actually used
        // instead, so a tier invented to mean "nerd only" fails
        // here rather than shipping as row-level mode depth.
        let tiers = Set(placed.map(\.placement.tier))
        #expect(tiers.isSubset(of: [.atRest, .showMore]))
    }
}
