import Foundation

// The layout cycle as a `RuleReachTable` (#453): one key, so a
// row reaches all profiles or a list, as the Space history does.

extension RuleReachTable where Value == [LayoutMode] {
    /// The family's one key.
    public static var modeCycleKey: String { "mode_cycle" }

    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func modeCycle(
        base: [LayoutMode],
        overrides: [(profile: String, override: [LayoutMode]?)]
    ) -> Self {
        var entries: [String: [String: [LayoutMode]?]] = [:]
        for (profile, override) in overrides {
            entries[profile] =
                override.map { [modeCycleKey: .some($0)] } ?? [:]
        }
        return Self(
            base: [modeCycleKey: base],
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base as the table now holds it.
    public var modeCycleBase: [LayoutMode] {
        base[Self.modeCycleKey] ?? ModeCycle.defaultList
    }

    /// `profile`'s override against the table's base; nil where it
    /// follows.
    public func modeCycleOverride(for profile: String) -> [LayoutMode]? {
        resolved(Self.modeCycleKey, for: profile).flatMap {
            ModeCycle.sparse($0, over: modeCycleBase)
        }
    }
}
