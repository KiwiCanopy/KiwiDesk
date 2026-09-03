import KiwiDeskCore

/// The rows the footer owes for drift the header already claims
/// (#1197): a screen setup the active profile stores no set for,
/// a built-in layout nothing has saved, a deleted match. None of
/// it lives in the draft `GuiConfig`, so `SettingsDraftDiff`
/// cannot see it; it is read off the model's resolution state
/// under the SAME predicate the header's ⚠ row uses
/// (`SettingsHeaderBar.showDivergence`), so the pill's count and
/// the header's claim cannot disagree — the contradiction this
/// closes. Each row anchors where the drift is visible: the
/// Monitors fingerprints row, or the Saved profiles card.
extension SettingsDiffRowSource {
    /// The instance discriminator of every drift row — keeps it
    /// apart from a config row on the same census key.
    static let driftInstance = "drift"

    static func driftRows(
        for model: SettingsModel
    ) -> [SettingsDiffRow] {
        guard model.profileDirty, !model.editingStoredProfile
        else { return [] }
        // The same ladder as `SettingsHeaderBar.statusText`,
        // minus the editing arms the guard above excludes.
        if model.activeStandard != nil {
            return [
                profileRow(
                    L(
                        "profile_header.status.built_in",
                        "Built-in layout — save as a profile to "
                            + "make it yours."
                    )
                )
            ]
        }
        if let name = model.activeProfile {
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
        }
        return [
            profileRow(
                L(
                    "profile_header.status.no_match",
                    "No profile matches this monitor setup."
                )
            )
        ]
    }

    private static func profileRow(_ note: String) -> SettingsDiffRow {
        SettingsDiffRow.note(
            .profiles(.profilesLoad),
            instance: driftInstance,
            label: L("diff.drift.profile", "Profile"),
            note: note
        )
    }
}
