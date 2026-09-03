import KiwiDeskCore

/// The rows the pill owes for `SettingsModel.profileDrift`
/// (#1197) — one per verdict, so the pill counts what the header
/// claims. `docs/design-decisions.md` ▸ *The save pill counts
/// what the header claims* argues the shape.
///
/// The sentences are the ROW's own, never the header's: a header
/// narrates a status line, a row narrates a change beside a
/// label, and borrowing across the two read as "Profile ·
/// Built-in layout — save as a profile to make it yours" (owner,
/// 2026-09-03). Each names what is missing and the button that
/// fixes it.
extension SettingsDiffRowSource {
    /// The instance discriminator of every drift row — keeps it
    /// apart from a config row on the same census key.
    static let driftInstance = "drift"

    static func driftRows(
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        guard let drift = model.profileDrift else { return [] }
        switch drift {
        case .builtIn:
            return [
                profileRow(
                    L(
                        "diff.drift.built_in",
                        "No profile covers these screens — a "
                            + "built-in layout is arranging "
                            + "them. %1$@ to keep it.",
                        saveAsNewLabel
                    )
                )
            ]
        case .screensUnsaved(let name):
            return [
                SettingsDiffRow.note(
                    .monitors(.fingerprints),
                    instance: driftInstance,
                    label: L("diff.drift.screens", "Screens"),
                    // A screen-count mismatch is the one drift
                    // Save cannot take up; the hint that greys
                    // Save says so, and the row says the same.
                    note: model.updateHint
                        ?? L(
                            "diff.drift.screens.unsaved",
                            "This screen setup isn't saved in "
                                + "\u{201C}%1$@\u{201D} yet.",
                            name
                        )
                )
            ]
        case .noMatch:
            return [
                profileRow(
                    L(
                        "diff.drift.no_match",
                        "No saved profile covers these screens. "
                            + "%1$@ to keep this setup.",
                        saveAsNewLabel
                    )
                )
            ]
        }
    }

    /// The footer button these rows send the user to. Both arms
    /// have no active profile, so `primarySaveAction` is
    /// `.saveAsNewProfile` and this IS the label on screen —
    /// interpolated rather than quoted (#818).
    private static var saveAsNewLabel: String {
        L("footer.save_as_new_profile", "Save as New Profile…")
    }

    /// Jumps to the Profiles ROOT: no control renders the
    /// composing Standard, and the Saved profiles card's one
    /// anchored control is Load, the verb that replaces a layout.
    private static func profileRow(_ note: String) -> SettingsDiffRow {
        SettingsDiffRow.note(
            .profiles(.profilesLoad),
            instance: driftInstance,
            label: L("diff.drift.profile", "Profile"),
            note: note,
            areaRoot: true
        )
    }
}
