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
/// the scope** (#678 decision items 14/15, #2654):
///
///  - *the whole list.* The moment a profile carries a single
///    shortcut override, the override affordance is live on
///    EVERY row of that list, not only the overridden one. A
///    user who has overridden one key is a user who overrides
///    keys; making them re-discover the affordance per row is
///    the thing this forbids.
///  - *the list, not the app.* Overriding a shortcut must not
///    turn a deeper surface on anywhere else, or the unlock
///    becomes something users trip by accident. App rules are
///    the nearest neighbour with the same override shape, so
///    they are the probe.
///
/// Both hold because the affordance keys off *editing a stored
/// profile*, never off a per-row flag or a window-wide depth.
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
        return (makeTestModel(core: core), core)
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

        // Every row of the list reads its reach, not just the
        // overridden one — the checklist is the LIST's, not the
        // row's (#1393). Each base row reads SHARED: a missing
        // checklist reads nil and a mis-keyed row reads not shared,
        // so the clause fails on either.
        for (_, lua) in baseCombos {
            let key = RuleReachTable<String>.keyID(
                layer: KeyLayer.defaultName,
                lua: lua
            )
            #expect(
                model.keyReach(key)?.shared == true,
                Comment(rawValue: "peer \(lua) has no shared reading")
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
                            // An action the base lacks, so Desk's
                            // own — a moved combo would leave the
                            // base row beside it (no deletions).
                            KeyBinding(
                                combo: "ctrl+alt+r",
                                lua: "KiwiDesk.reload_config()",
                                kind: .custom
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

        // The overridden shortcut is Desk's own, not the shared one.
        let own = RuleReachTable<String>.keyID(
            layer: KeyLayer.defaultName,
            lua: "KiwiDesk.reload_config()"
        )
        #expect(model.keyReach(own)?.shared == false)
        // The neighbouring list keeps its rules shared — the
        // capability stayed in its own list (#1393's checklist).
        // `== true` fails on a missing reading, so the clause
        // cannot pass on an absent checklist.
        #expect(model.config.appRules.count == 2)
        #expect(
            model.config.appRules.keys.allSatisfy {
                model.spaceReach($0)?.shared == true
            }
        )
    }

    /// Nothing in the Shortcuts area is withheld by a depth
    /// setting (#2654): the census tiers say where a row sits, and
    /// a tier invented to mean "experts only" fails here rather
    /// than shipping as row-level depth.
    @Test("Shortcuts places rows on the three drawn tiers only")
    func shortcutsTiersAreDrawn() {
        let placed = SettingKey.allCases.filter {
            $0.placement.area == .shortcuts
        }
        #expect(!placed.isEmpty)
        // `.immediate` surfaces a row the moment the config holds
        // the thing — config presence expands the surface.
        let tiers = Set(placed.map(\.placement.tier))
        #expect(
            tiers.isSubset(of: [.atRest, .showMore, .immediate])
        )
        // Vacuity: `.immediate` must actually be in use.
        #expect(tiers.contains(.immediate))
    }
}
