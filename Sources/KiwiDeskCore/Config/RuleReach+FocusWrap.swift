import Foundation

// The focus-wrap setting as a `RuleReachTable` (#2493): one key,
// so a row reaches all profiles or a list, as the Space history
// does.

extension RuleReachTable where Value == FocusWrap {
    /// The family's one key.
    public static var focusWrapKey: String { "focus_wrap" }

    /// The family, from the stored base and each profile's sparse
    /// override.
    public static func focusWrap(
        base: FocusWrap,
        overrides: [(profile: String, override: FocusWrap?)]
    ) -> Self {
        var entries: [String: [String: FocusWrap?]] = [:]
        for (profile, override) in overrides {
            entries[profile] =
                override.map { [focusWrapKey: .some($0)] } ?? [:]
        }
        return Self(
            base: [focusWrapKey: base],
            entries: entries,
            profiles: overrides.map(\.profile)
        )
    }

    /// The base as the table now holds it.
    public var focusWrapBase: FocusWrap {
        base[Self.focusWrapKey] ?? .defaultMode
    }

    /// `profile`'s override against the table's base; nil where it
    /// follows.
    public func focusWrapOverride(for profile: String) -> FocusWrap? {
        resolved(Self.focusWrapKey, for: profile).flatMap {
            .sparse($0, over: focusWrapBase)
        }
    }
}
