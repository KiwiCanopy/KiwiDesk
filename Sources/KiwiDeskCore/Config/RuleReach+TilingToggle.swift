import Foundation

// The tiling toggle's start value and its two hide ticks as
// `RuleReachTable`s (#3089): the base is `gui.json`'s app-wide
// `tiling` group and each profile's value its sparse override, so
// a row reaches all profiles or a list, as Wrap focus does. The
// start is one family and the ticks a second over two keys.

extension RuleReachTable where Value == Bool {
    /// The start family's one key.
    public static var tilingStartKey: String { "tiling.start" }
    /// The hide family's keys.
    public static var offHidesBordersKey: String {
        "tiling.off_hides_borders"
    }
    public static var offHidesBarsKey: String { "tiling.off_hides_bars" }

    /// The start family, from the app-wide base and each profile's
    /// own value.
    public static func tilingStart(
        base: Bool,
        overrides: [(profile: String, override: Bool?)]
    ) -> Self {
        tilingFamily(
            base: [tilingStartKey: base],
            overrides: overrides.map {
                ($0.profile, [tilingStartKey: $0.override])
            }
        )
    }

    /// The hide family, from the two app-wide bases and each
    /// profile's own ticks.
    public static func tilingOffHides(
        base: (borders: Bool, bars: Bool),
        overrides: [(profile: String, settings: TilingToggleSettings)]
    ) -> Self {
        tilingFamily(
            base: [
                offHidesBordersKey: base.borders,
                offHidesBarsKey: base.bars,
            ],
            overrides: overrides.map {
                (
                    $0.profile,
                    [
                        offHidesBordersKey: $0.settings.offHidesBorders,
                        offHidesBarsKey: $0.settings.offHidesBars,
                    ]
                )
            }
        )
    }

    private static func tilingFamily(
        base: [String: Bool],
        overrides: [(String, [String: Bool?])]
    ) -> Self {
        var entries: [String: [String: Bool?]] = [:]
        for (profile, values) in overrides {
            entries[profile] = values.compactMapValues { $0 }
                .mapValues { .some($0) }
        }
        return Self(
            base: base,
            entries: entries,
            profiles: overrides.map(\.0)
        )
    }

    /// `profile`'s own value for `key` as the table holds it; nil
    /// where it follows.
    public func tilingOwn(_ key: String, for profile: String) -> Bool? {
        entries[profile]?[key] ?? nil
    }

    /// `key`'s base as the table now holds it, over `fallback`.
    public func tilingBase(_ key: String, fallback: Bool) -> Bool {
        base[key] ?? fallback
    }

    /// `profile`'s own value for `key` against the table's base;
    /// nil where it follows.
    public func tilingOverride(
        _ key: String,
        for profile: String,
        fallback: Bool
    ) -> Bool? {
        let shared = tilingBase(key, fallback: fallback)
        return resolved(key, for: profile).flatMap {
            $0 == shared ? nil : $0
        }
    }
}
