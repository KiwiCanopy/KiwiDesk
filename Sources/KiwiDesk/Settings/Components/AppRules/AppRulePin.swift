import KiwiDeskCore

/// The Space a new "Open in a Space" rule takes (#1022, #1608).
enum AppRulePin {
    /// `GuiConfig.fallbackSpace`, the #68 rehome target, while
    /// this config still lists it; else the first Space; nil with
    /// none declared. That MIRRORS Core's rehome preference
    /// (`pruneSpaces(preferring:)`) rather than sharing it, so a
    /// change to Core's survivor rule is a change here too.
    static func engagedSpace(_ config: GuiConfig) -> SpaceID? {
        if let fallback = config.fallbackSpace,
            config.spaces.contains(fallback)
        {
            return fallback
        }
        return config.spaces.first
    }
}
