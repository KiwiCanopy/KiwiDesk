import Foundation

// The Space history setting as a `RuleReachTable` (#1655): one
// key, so a row reaches all profiles or a list, as a scroll
// gesture's field does.

extension RuleReachTable where Value == SpaceHistoryKind {
    /// The family's one key.
    public static var spaceHistoryKey: String { "space_history" }

    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func spaceHistory(
        base: SpaceHistoryKind,
        overrides: [(profile: String, override: SpaceHistoryKind?)]
    ) -> Self {
        var entries: [String: [String: SpaceHistoryKind?]] = [:]
        for (profile, override) in overrides {
            entries[profile] =
                override.map { [spaceHistoryKey: .some($0)] } ?? [:]
        }
        return Self(
            base: [spaceHistoryKey: base],
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base as the table now holds it.
    public var spaceHistoryBase: SpaceHistoryKind {
        base[Self.spaceHistoryKey] ?? .defaultKind
    }

    /// `profile`'s override against the table's base; nil where it
    /// follows.
    public func spaceHistoryOverride(
        for profile: String
    ) -> SpaceHistoryKind? {
        let own = resolved(Self.spaceHistoryKey, for: profile)
        return own == spaceHistoryBase ? nil : own
    }
}
