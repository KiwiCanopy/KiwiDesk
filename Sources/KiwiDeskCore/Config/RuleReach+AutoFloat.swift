import Foundation

// The automatic-float escape as `RuleReachTable`s (#2173): the Tile
// list is the float family's shape with app-only entries, and the
// switch one key, as the Space history setting is.

extension RuleReachTable where Value == [String] {
    /// The Tile family: per app, its one app-only entry.
    public static func tileRules(
        base: [String],
        overrides: [(profile: String, override: RuleListOverride?)]
    ) -> Self {
        floatRules(base: base, overrides: overrides)
    }
}

extension RuleReachTable where Value == Bool {
    /// The switch's one key.
    public static var floatAutomaticallyKey: String { "float_automatically" }

    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func floatAutomatically(
        base: Bool,
        overrides: [(profile: String, override: Bool?)]
    ) -> Self {
        var entries: [String: [String: Bool?]] = [:]
        for (profile, override) in overrides {
            entries[profile] =
                override.map { [floatAutomaticallyKey: .some($0)] } ?? [:]
        }
        return Self(
            base: [floatAutomaticallyKey: base],
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base as the table now holds it.
    public var floatAutomaticallyBase: Bool {
        base[Self.floatAutomaticallyKey] ?? true
    }

    /// `profile`'s override against the table's base; nil where it
    /// follows.
    public func floatAutomaticallyOverride(for profile: String) -> Bool? {
        resolved(Self.floatAutomaticallyKey, for: profile).flatMap {
            $0 == floatAutomaticallyBase ? nil : $0
        }
    }
}
