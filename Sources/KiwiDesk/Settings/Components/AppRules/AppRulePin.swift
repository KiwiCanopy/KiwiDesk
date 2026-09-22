import KiwiDeskCore

/// The Space-pin half of an app rule (#1022).
///
/// A rule that neither floats nor pins says nothing — it is the
/// default behaviour of every unruled app, which the card's own
/// empty note already states. So tiling REQUIRES a pin, and this
/// is the one place both halves of that are derived: which Space
/// an auto-engaged pin takes, and when the checkbox may not be
/// released.
enum AppRulePin {
    /// Space an auto-engaged pin selects: the rehome target #68
    /// already designates, never an arbitrary list position. The
    /// membership test is not defensive tidying — a profile whose
    /// `fallbackSpace` names a space this config no longer lists
    /// would otherwise author a pin to a space the menu cannot
    /// show.
    static func defaultSpace(_ config: GuiConfig) -> SpaceID? {
        if let fallback = config.fallbackSpace,
            config.spaces.contains(fallback)
        {
            return fallback
        }
        return config.spaces.first
    }

    /// Whether tiling holds this row's pin engaged.
    ///
    /// Two states it must not claim, both real instructions
    /// rather than empty rows. In override mode the stored nil is
    /// the TOMBSTONE — it un-pins an app the base profile pins —
    /// so "tiles, no pin" says something there. And with no
    /// Spaces declared there is nothing to pin to, so tiling
    /// cannot force one; the card points at where to declare one
    /// instead.
    static func isLocked(
        floats: Bool,
        isOverride: Bool,
        hasSpaces: Bool
    ) -> Bool {
        !floats && !isOverride && hasSpaces
    }
}
