import KiwiDeskCore
import SwiftUI

/// Reset and recovery actions in General ▸ Advanced (#606,
/// #634). Restore sits AFTER Reset All: Reset All earns its name
/// by leaving `init.lua` and the palettes standing, and Restore
/// replaces the palettes too — the widest action comes last, or
/// the ordering stops telling a user which button is safe.
/// Danger is signaled by the dialog's destructive role, never a
/// resting red button (house convention).
///
/// Ladder order progresses from non-destructive to widest impact
/// (`GeneralSection+Backup`).
extension GeneralSection {
    @ViewBuilder var resetLadder: some View {
        Divider()
        discardArrangementRow
        Divider()
        resetAllRow
        Divider()
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
            // `discard.cancel`: most catalogs translate the
            // latter as "Continue editing" rather than
            // "Cancel" — right for the staged-edit gate it was
            // minted for, nonsense on a dialog with nothing
            // being edited. Read the value, do not trust a
            // count: this comment carried "six locales" and it
            // was seven (`grep discard.cancel
            // Sources/KiwiDeskCore/Resources/Locales/*.json`).
            // Accepted coupling: rewording the Spaces dialog's
            // Cancel rewords this one too — fine while both
            // mean a plain "Cancel"; mint a key if either
            // drifts.
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
