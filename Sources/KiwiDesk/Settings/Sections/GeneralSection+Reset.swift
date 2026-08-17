import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced, last rows: the reset escape hatches (#634)
/// and, since #606, the restore. The disclosure reads as an
/// ascending-severity ladder — Reveal (read-only), Edit init.lua
/// (a mode switch), Export a backup (read-only), Discard Saved
/// Window Arrangement (regenerating state), Reset All Settings
/// (irreversible wipe), Restore from Backup (replaces everything
/// saved, palettes included) — so the hatches come last.
///
/// **Restore sits after Reset All, and the naming paragraph below
/// is why.** Reset All earns its name by leaving `init.lua` and
/// the palettes standing; Restore replaces the palettes too, so on
/// the axis this file already names it is the wider action. Adding
/// it anywhere else would put the harsher action before the milder
/// one and break the one thing this ordering tells a user.
///
/// Naming follows iOS Settings' "Reset All Settings" (config
/// wiped, content kept) rather than "Total reset": once
/// `init.lua` and the palettes visibly survive, a total-reset
/// label would read as a lie. Danger is signaled by the
/// confirmation dialog's destructive role, never a resting red
/// button (house convention). Tier 1 confirms nothing — it is
/// strictly less consequential than the unconfirmed
/// single-profile delete, since the files regenerate within one
/// autosave cycle.
extension GeneralSection {
    @ViewBuilder var resetLadder: some View {
        Divider()
        discardArrangementRow
        Divider()
        resetAllRow
        Divider()
        // The ladder's last rung, added with #606, and the reason
        // the enumeration above now ends here: Restore replaces
        // the palettes Reset All deliberately spares — which is
        // the ceiling that gives Reset All its name — so it is the
        // most destructive action in the drawer, not merely
        // another one. `GeneralSection+Backup` carries the
        // argument and the cost.
        restoreBackupRow
    }

    private var discardArrangementRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    model.discardSavedArrangement()
                } label: {
                    Label(
                        L(
                            "general.advanced.discard_arrangement",
                            "Discard Saved Window Arrangement"
                        ),
                        systemImage: "clock.arrow.circlepath"
                    )
                }
                .settingsActionButton()
                HelpButton(
                    explanation: L(
                        "general.advanced.discard_arrangement.help",
                        "If windows come back in the wrong "
                            + "Spaces or positions after a "
                            + "restart or wake, a stale saved "
                            + "arrangement is the usual cause. "
                            + "Discarding it makes the next "
                            + "restore start clean — settings "
                            + "and profiles are untouched."
                    ),
                    subject: L(
                        "general.advanced.discard_arrangement",
                        "Discard Saved Window Arrangement"
                    )
                )
            }
            Text(
                L(
                    "general.advanced.discard_arrangement.caption",
                    "Clears the arrangement KiwiDesk remembered "
                        + "from your last session or wake, "
                        + "without changing any settings."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    private var resetAllRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    confirmingReset = true
                } label: {
                    Label(
                        L(
                            "general.advanced.reset_all",
                            "Reset All Settings…"
                        ),
                        systemImage: "arrow.counterclockwise"
                    )
                }
                .settingsActionButton()
                HelpButton(
                    explanation: L(
                        "general.advanced.reset_all.help",
                        "The last resort when KiwiDesk keeps "
                            + "misbehaving and discarding the "
                            + "saved arrangement didn't help: "
                            + "everything returns to a "
                            + "known-good default, the same "
                            + "state as a first launch."
                    ),
                    subject: L(
                        "general.advanced.reset_all",
                        "Reset All Settings…"
                    )
                )
            }
            Text(
                L(
                    "general.advanced.reset_all.caption",
                    "Deletes your profiles, Spaces, layouts, "
                        + "and keybindings, then starts fresh "
                        + "with KiwiDesk's defaults. Doesn't "
                        + "touch init.lua or your color "
                        + "palettes."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        // Its own dialog, never the shared discard gate: that
        // gate only fires while `isDirty`, and this must
        // confirm every time (the "Adopt" precedent).
        .confirmationDialog(
            L(
                "general.advanced.reset_all.confirm.title",
                "Reset all KiwiDesk settings?"
            ),
            isPresented: $confirmingReset,
            titleVisibility: .visible
        ) {
            Button(
                L(
                    "general.advanced.reset_all.confirm",
                    "Reset Settings"
                ),
                role: .destructive
            ) {
                model.resetAllSettings()
            }
            // `spaces.delete_confirm.cancel`, not
            // `discard.cancel`: the latter translates as
            // "Continue editing" in six locales — right for
            // the staged-edit gate, nonsense here. Accepted
            // coupling: rewording the Spaces dialog's Cancel
            // rewords this one too — fine while both mean a
            // plain "Cancel"; mint a key if either drifts.
            Button(
                L("spaces.delete_confirm.cancel", "Cancel"),
                role: .cancel
            ) {}
        } message: {
            Text(
                L(
                    "general.advanced.reset_all.confirm.message",
                    "This deletes every saved profile, your "
                        + "Spaces, layouts, and keybindings, "
                        + "and forgets any window arrangement "
                        + "KiwiDesk remembered — then starts "
                        + "over with its starter defaults, the "
                        + "same state as a first launch. Your "
                        + "init.lua and color palettes are "
                        + "kept. The old files go to the "
                        + "Trash."
                )
            )
        }
    }
}
