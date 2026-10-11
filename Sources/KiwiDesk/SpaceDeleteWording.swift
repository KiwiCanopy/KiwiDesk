import KiwiDeskCore

/// The words a Space's delete confirmation uses — Settings ▸ Spaces'
/// trash and a Space chip's Delete of a profile Space (#1790) ask
/// in the same words.
@MainActor
enum SpaceDeleteWording {
    /// What a delete of a Space with its own settings also removes,
    /// with the role names interpolated (#818).
    static var overridesMessage: String {
        L(
            "spaces.delete_confirm.message",
            "This Space has customized settings — its "
                + "layout overrides, screen pin, and any "
                + "\u{201C}%1$@\u{201D} or \u{201C}%2$@\u{201D} "
                + "role are removed too. You "
                + "can add the Space back, but not its "
                + "settings.",
            L("monitor_card.follows_main", "Follows main screen"),
            L("spaces.fallback_badge", "Fallback")
        )
    }

    static var delete: String { L("spaces.delete_confirm.delete", "Delete") }
    static var cancel: String { L("spaces.delete_confirm.cancel", "Cancel") }
}
