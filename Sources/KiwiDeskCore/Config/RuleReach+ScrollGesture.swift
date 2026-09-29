import Foundation

// The scroll gestures as a `RuleReachTable` (#1656): a key is one
// `ScrollGestureField`. The base holds every field, so no profile
// ever leaves one out — a row reaches all profiles or a list.

extension RuleReachTable where Value == ScrollGestureValue {
    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func scrollGestures(
        base: ScrollGestureBase,
        overrides: [(profile: String, override: ScrollGestureOverride?)]
    ) -> Self {
        var entries: [String: [String: ScrollGestureValue?]] = [:]
        for (profile, override) in overrides {
            entries[profile] = (override?.fields ?? [:]).mapValues {
                .some($0)
            }
        }
        return Self(
            base: base.fields,
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base as the table now holds it, over `original` for a
    /// field the table lacks.
    public func scrollGestureBase(
        original: ScrollGestureBase
    ) -> ScrollGestureBase {
        original.writing(base)
    }

    /// `profile`'s override against the table's base; nil where
    /// nothing diverges.
    public func scrollGestureOverride(
        for profile: String,
        original: ScrollGestureBase
    ) -> ScrollGestureOverride? {
        let shared = scrollGestureBase(original: original)
        return ScrollGestureOverride.diff(
            base: shared,
            edited: shared.writing(resolved(for: profile))
        )
    }
}
