import Foundation

// The gesture bindings as a `RuleReachTable` (#3225): a key is one
// `GestureKey` by its spelling, its value the whole action. The base
// is the seeds with `gui.json`'s map laid over them, so a seed the
// base turns off is a key the base lacks, and a profile's tombstone
// is a profile leaving the key out. It holds what the files say: a
// binding `GestureSeeds.resolved` refuses still reaches, and its row
// narrates the refusal.

extension RuleReachTable where Value == GestureAction {
    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func gestures(
        base: GestureMap,
        overrides: [(profile: String, override: GestureMap?)]
    ) -> Self {
        var entries: [String: [String: GestureAction?]] = [:]
        for (profile, override) in overrides {
            var own: [String: GestureAction?] = [:]
            for (key, entry) in override?.entries ?? [:] {
                own.updateValue(entry.action, forKey: key.spelling)
            }
            entries[profile] = own
        }
        return Self(
            base: gestureSeedsUnder(base),
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// `map` laid over the seeds, keyed by spelling.
    public static func gestureSeedsUnder(
        _ map: GestureMap
    ) -> [String: GestureAction] {
        var out: [String: GestureAction] = [:]
        for (key, action) in GestureSeeds.seeds {
            out[key.spelling] = action
        }
        for (key, entry) in map.entries {
            out[key.spelling] = entry.action
        }
        return out
    }

    /// The stored map that lays `resolved` over the seeds: a key
    /// equal to its seed is left to the seed, a seed `resolved`
    /// lacks is turned off.
    public static func gestureMap(
        over resolved: [String: GestureAction]
    ) -> GestureMap {
        var map = GestureMap()
        for key in GestureSeeds.seeds.keys
        where resolved[key.spelling] == nil {
            map[key] = .unbound
        }
        for (spelling, action) in resolved {
            guard let key = GestureKey(spelling: spelling) else { continue }
            if GestureSeeds.seeds[key] != action { map[key] = .bound(action) }
        }
        return map
    }

    /// The base map: `original` with each touched key rebuilt
    /// against the seeds, so an untouched entry keeps its stored
    /// form.
    public func gestureBase(original: GestureMap) -> GestureMap {
        guard !baseTouched.isEmpty else { return original }
        var map = original
        let rebuilt = Self.gestureMap(over: base)
        for spelling in baseTouched {
            guard let key = GestureKey(spelling: spelling) else { continue }
            map[key] = rebuilt[key]
        }
        return map
    }

    /// `profile`'s override as the table holds it; nil when empty.
    /// The entries are the file's own, so an untouched one is
    /// written back as it was read.
    public func gestureOverride(for profile: String) -> GestureMap? {
        var map = GestureMap()
        for (spelling, entry) in entries[profile] ?? [:] {
            guard let key = GestureKey(spelling: spelling) else { continue }
            map[key] = entry.map(GestureEntry.bound) ?? .unbound
        }
        return map.isEmpty ? nil : map
    }
}
