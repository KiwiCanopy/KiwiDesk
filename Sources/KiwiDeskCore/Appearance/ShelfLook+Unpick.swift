import Foundation

/// Taking a pick back (#2745): what a look pick reaches, returned to
/// a baseline, and nothing else.
extension ShelfLook {
    /// `current` with every look path — motion included — and every
    /// colour returned to `before`, then the writes `apply` makes
    /// beyond its keys (`restorePickReach`).
    public static func unpicked(
        _ current: TilingSettings,
        to before: TilingSettings
    ) -> TilingSettings {
        var settings = current
        LookBody(of: before).named("").apply(to: &settings)
        restorePickReach(of: &settings, from: before)
        return settings
    }

    /// The writes a pick makes beyond its keys — every glass leaf,
    /// the per-layout indicators, the origin — put back from
    /// `before`: the one list every unpaint reads.
    static func restorePickReach(
        of settings: inout TilingSettings,
        from before: TilingSettings
    ) {
        for leaf in TilingSettings.liquidGlassLeaves {
            settings[keyPath: leaf] = before[keyPath: leaf]
        }
        for leaf in TilingSettings.layoutIndicatorLeaves {
            settings[keyPath: leaf] = before[keyPath: leaf]
        }
        settings.lookOrigin = before.lookOrigin
    }
}
