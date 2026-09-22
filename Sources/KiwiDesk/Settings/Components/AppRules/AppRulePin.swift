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
    /// Space a pin takes when it engages, for a row whose base
    /// pins `inherited` (nil outside override mode).
    ///
    /// The base's own Space comes first, and that is not a
    /// nicety: a tombstoned row draws and re-writes this value,
    /// so falling through to the designated Space would draw the
    /// wrong one and, on re-check, silently REPLACE the inherited
    /// pin with it instead of restoring it (ui-designer,
    /// 2026-09-22).
    ///
    /// Otherwise the designated fallback, `GuiConfig.fallbackSpace`
    /// — the #68 rehome target, reused rather than coining a
    /// second notion of "the default Space" — and its membership
    /// test is not defensive tidying: a profile whose
    /// `fallbackSpace` names a space this config no longer lists
    /// would otherwise author a pin to a space the menu cannot
    /// show. It MIRRORS Core's rehome preference
    /// (`pruneSpaces(preferring:)`) rather than sharing it; the
    /// two are not held equal, so a change to Core's survivor
    /// rule is a change here too.
    static func engagedSpace(
        _ config: GuiConfig,
        inherited: SpaceID? = nil
    ) -> SpaceID? {
        if let inherited, config.spaces.contains(inherited) {
            return inherited
        }
        if let fallback = config.fallbackSpace,
            config.spaces.contains(fallback)
        {
            return fallback
        }
        return config.spaces.first
    }

    /// What the pin checkbox may do on a row.
    ///
    /// Three cases, not a `Bool`, because the middle one is where
    /// a two-state answer shipped a live checkbox that silently
    /// wrote nothing: with no Spaces declared the pin is neither
    /// held engaged nor usable, and "grey, don't hide" forbids a
    /// control that pretends (architect + ui-designer review,
    /// 2026-09-22).
    enum Verdict: Equatable {
        /// Tiling holds the pin engaged; it may not be released.
        case locked
        /// The user's to set or clear.
        case free
        /// Nothing to pin to — inert, and the card says where to
        /// declare a Space.
        case unavailable
    }

    /// Two states that must NOT be `locked`, both real
    /// instructions rather than empty rows. In override mode the
    /// stored nil is the TOMBSTONE — it un-pins an app the base
    /// profile pins — so "tiles, no pin" says something there.
    /// And with no Spaces declared there is nothing to pin to.
    static func verdict(
        floats: Bool,
        isOverride: Bool,
        hasSpaces: Bool
    ) -> Verdict {
        guard hasSpaces else { return .unavailable }
        return floats || isOverride ? .free : .locked
    }
}
