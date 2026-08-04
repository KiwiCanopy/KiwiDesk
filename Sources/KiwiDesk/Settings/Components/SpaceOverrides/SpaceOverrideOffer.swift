import KiwiDeskCore

/// Whether the per-space override affordance is *offered* — the
/// #678 8c capability unlock, for the Spaces list.
///
/// > Easy withholds only the *offer* to create an override, and
/// > the offer unlocks itself per list the moment the profile has
/// > one … collapsing away when the last override is cleared.
///
/// `Customize…` rendered on every space row in both modes, so
/// every user met per-space exception bookkeeping whether or not
/// they had any exceptions.
///
/// Note what this is NOT gating on any more: Layout Defaults
/// itself became `.simple` (owner ruling 2026-08-04), because
/// those parameters are how people learn what a tiling manager
/// does. Editing one layout's defaults is the feature; editing
/// them per space is bookkeeping about exceptions, and that is
/// what stays behind the offer.
///
/// **Three properties, and the cheap implementation breaks two of
/// them** (`ShortcutsCapabilityUnlockTests` names the same trap
/// for the shortcut column):
///
///  - *the whole list.* One override anywhere unlocks the
///    affordance on EVERY space row, not just the overridden
///    one. A user who has overridden one space is a user who
///    overrides spaces; making them re-discover the affordance
///    per row is the thing this forbids. Hence a list-wide
///    predicate rather than the per-row `count > 0` the button
///    already had in hand.
///  - *the list, not the app.* A space override must not turn a
///    deeper surface on anywhere else — the failure mode is "the
///    mode becomes something users lose by accident".
///  - *the mode never changes what runs.* This gates the OFFER
///    only. Overrides already saved keep resolving in Simple,
///    untouched and unreachable-from-here — which is why the
///    unlock has to consult the saved state rather than the mode
///    alone, or a Simple user with overrides could neither see
///    nor clear them.
///
/// Hidden rather than greyed when withheld (owner ruling
/// 2026-08-04), against the standing "grey, don't hide" default:
/// mode-withheld surface is *absent* everywhere else in this
/// window — a `.powerUser` area has no Home card in Simple, it is
/// not a dimmed one — because the mode adds surface rather than
/// expanding it. A permanently dead button on every space row is
/// the clutter the mode split exists to remove.
enum SpaceOverrideOffer {
    /// `spaces` is the profile's whole list, so that clearing the
    /// last override anywhere collapses the affordance
    /// everywhere — the "collapsing away" half of 8c, which a
    /// per-row test cannot express.
    static func isOffered(
        mode: SettingsMode,
        settings: TilingSettings,
        spaces: [SpaceID]
    ) -> Bool {
        if mode == .powerUser { return true }
        return spaces.contains {
            settings.overrideFieldCount(for: $0) > 0
        }
    }
}
