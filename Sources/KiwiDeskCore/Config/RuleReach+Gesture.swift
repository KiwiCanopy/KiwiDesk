import Foundation

// The gesture bindings as a `RuleReachTable` (#3225): a key is one
// binding by its `LayerGestureKey` spelling (#3535), its value the
// whole action. The base is each layer's seeds on the stored
// shortcut base (#3444) with `gui.json`'s map laid over them, so a
// seed the base turns off is a key the base lacks, and a profile's
// tombstone is a profile leaving the key out. It holds what the
// files say: a binding `GestureSeeds.resolved` refuses still
// reaches, and its row narrates the refusal.

extension RuleReachTable where Value == GestureAction {
    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func gestures(
        base: LayerGestures,
        overrides: [(profile: String, override: LayerGestures?)],
        shortcutBase: ShortcutBase
    ) -> Self {
        var entries: [String: [String: GestureAction?]] = [:]
        for (profile, override) in overrides {
            var own: [String: GestureAction?] = [:]
            for (layer, map) in override?.maps ?? [:] {
                for (key, entry) in map.entries {
                    own.updateValue(
                        entry.action,
                        forKey: LayerGestureKey(layer, key).spelling
                    )
                }
            }
            entries[profile] = own
        }
        return Self(
            base: gestureSeedsUnder(base, shortcutBase: shortcutBase),
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// `maps` laid over each layer's seeds on `shortcutBase`, keyed
    /// by `LayerGestureKey` spelling.
    public static func gestureSeedsUnder(
        _ maps: LayerGestures,
        shortcutBase: ShortcutBase
    ) -> [String: GestureAction] {
        var out: [String: GestureAction] = [:]
        for (key, action) in GestureSeeds.seeds(on: shortcutBase) {
            out[LayerGestureKey(KeyLayer.defaultName, key).spelling] =
                action
        }
        for (layer, map) in maps.maps {
            for (key, entry) in map.entries {
                out[LayerGestureKey(layer, key).spelling] = entry.action
            }
        }
        return out
    }

    /// The stored maps that lay `resolved` over each layer's seeds
    /// on `shortcutBase`: a key equal to its seed is left to the
    /// seed, a seed `resolved` lacks is turned off.
    public static func gestureMap(
        over resolved: [String: GestureAction],
        shortcutBase: ShortcutBase
    ) -> LayerGestures {
        let seeds = GestureSeeds.seeds(on: shortcutBase)
        var maps = LayerGestures()
        let defaultLayer = KeyLayer.defaultName
        for key in seeds.keys {
            let spelling = LayerGestureKey(defaultLayer, key).spelling
            if resolved[spelling] == nil {
                maps[defaultLayer][key] = .unbound
            }
        }
        for (spelling, action) in resolved {
            guard let key = LayerGestureKey(spelling: spelling) else {
                continue
            }
            let seed = GestureSeeds.seeds(
                on: shortcutBase,
                layer: key.layer
            )[key.key]
            if seed != action { maps[key.layer][key.key] = .bound(action) }
        }
        return maps
    }

    /// The base maps: `original` with each touched key rebuilt
    /// against the seeds, so an untouched entry keeps its stored
    /// form.
    public func gestureBase(
        original: LayerGestures,
        shortcutBase: ShortcutBase
    ) -> LayerGestures {
        guard !baseTouched.isEmpty else { return original }
        var maps = original
        let rebuilt = Self.gestureMap(over: base, shortcutBase: shortcutBase)
        for spelling in baseTouched {
            guard let key = LayerGestureKey(spelling: spelling) else {
                continue
            }
            maps[key.layer][key.key] = rebuilt[key.layer][key.key]
        }
        return maps
    }

    /// `profile`'s override as the table holds it; nil when empty.
    /// The entries are the file's own, so an untouched one is
    /// written back as it was read.
    public func gestureOverride(for profile: String) -> LayerGestures? {
        var maps = LayerGestures()
        for (spelling, entry) in entries[profile] ?? [:] {
            guard let key = LayerGestureKey(spelling: spelling) else {
                continue
            }
            maps[key.layer][key.key] =
                entry.map(GestureEntry.bound) ?? .unbound
        }
        return maps.isEmpty ? nil : maps
    }
}
