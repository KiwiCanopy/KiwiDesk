import KiwiDeskCore

/// The rows the pill owes for `SettingsModel.profileDrift`
/// (#1197) — one per verdict, so the pill counts what the header
/// claims. `docs/design-decisions.md` ▸ *The save pill counts
/// what the header claims* argues the shape.
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
                        "profile_header.status.built_in",
                        "Built-in layout — save as a profile to "
                            + "make it yours."
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
                        "profile_header.status.no_match",
                        "No profile matches this monitor setup."
                    )
                )
            ]
        }
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
