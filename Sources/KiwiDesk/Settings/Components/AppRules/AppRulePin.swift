import KiwiDeskCore

/// The Space-pin half of an app rule (#1022).
///
/// A rule that neither floats nor names a Space says nothing —
/// it is the default behaviour of every unruled app, which the
/// card's own empty note already states. So tiling REQUIRES a
/// Space, and this is the one place both halves of that are
/// derived: which Space an engaged assignment takes, and whether
/// the row must hold one.
enum AppRulePin {
    /// Space a pin takes when it engages, for a row whose base
    /// pins `inherited` (nil outside override mode).
    ///
    /// The base's own Space comes first: a tombstoned row draws
    /// and re-writes this value, so falling through to the
    /// designated Space would silently REPLACE the inherited pin
    /// rather than restore it. Otherwise
    /// `GuiConfig.fallbackSpace`, the #68 rehome target, while
    /// this config still lists it. That MIRRORS Core's rehome
    /// preference (`pruneSpaces(preferring:)`) rather than
    /// sharing it, so a change to Core's survivor rule is a
    /// change here too.
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

    /// Whether a row must hold a Space pin. Three cases, not a
    /// `Bool`: with no Spaces declared the pin is neither held
    /// nor settable, and a two-state answer shipped a live
    /// control that silently wrote nothing (#1022).
    enum Verdict: Equatable {
        /// The row tiles, so the pin is what makes it a rule: a
        /// write engages one, and no clear is offered.
        case required
        /// The rule survives without a pin; the user's to clear.
        case optional
        /// Nothing to pin to — inert, and the card says where to
        /// declare a Space.
        case unavailable
    }

    /// A floating row is `.optional`, and so is every row in
    /// override mode, where the stored nil is the TOMBSTONE that
    /// un-pins an app the base profile pins.
    static func verdict(
        floats: Bool,
        isOverride: Bool,
        hasSpaces: Bool
    ) -> Verdict {
        guard hasSpaces else { return .unavailable }
        return floats || isOverride ? .optional : .required
    }
}
