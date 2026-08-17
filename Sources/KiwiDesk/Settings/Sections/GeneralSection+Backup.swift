import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: export a backup, and restore one (#606).
///
/// **The two rows do not sit together, and that is the design.**
/// `GeneralSection+Reset` states the drawer's invariant and
/// enumerates it — an ascending-severity ladder, hatches last. So
/// Export sits with the read-only tools above the ladder, while
/// **Restore is the ladder's final rung, after Reset All
/// Settings**: it is the most destructive action in the drawer.
/// The proof is in that file's own doc comment, which is why this
/// is not a taste call — Reset All is *named* "Reset All Settings"
/// rather than "Total reset" because "once `init.lua` and the
/// palettes visibly survive, a total-reset label would read as a
/// lie". Palettes surviving is that action's stated ceiling, and
/// Restore replaces them.
///
/// The cost is that the two halves of one feature are apart, so
/// someone who exported scrolls past two destructive rows to find
/// the way back. Accepted: the alternative inverts the one
/// invariant that tells a user which button is safe to click.
extension GeneralSection {
    // MARK: - Export (read-only, above the ladder)

    var exportBackupRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    backupError = model.exportBackup()
                } label: {
                    Label(
                        L(
                            "general.advanced.backup.export",
                            "Export KiwiDesk Backup…"
                        ),
                        systemImage: "square.and.arrow.up"
                    )
                }
                .settingsActionButton()
                HelpButton(
                    // A concept, not a live fact, which is what
                    // `ui-patterns.md` gives the `?`. It is also
                    // the defusing of a real misread: "KiwiDesk
                    // Backup" pattern-matches "iCloud Backup" —
                    // proper names for automatic, ongoing systems
                    // — and KiwiDesk keeps none.
                    explanation: L(
                        "general.advanced.backup.export.help",
                        "A one-time snapshot, saved to a file you "
                            + "choose. KiwiDesk doesn't keep "
                            + "backups on its own — export again "
                            + "whenever you want an up-to-date "
                            + "copy."
                    ),
                    subject: L(
                        "general.advanced.backup.export",
                        "Export KiwiDesk Backup…"
                    )
                )
            }
            Text(
                L(
                    "general.advanced.backup.export.caption",
                    "Saves your settings, profiles, and color "
                        + "palettes to a file you choose. Doesn't "
                        + "include init.lua."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }

    // MARK: - Restore (the ladder's final rung)

    var restoreBackupRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Button {
                    switch model.readBackupToRestore() {
                    case .success(let bundle):
                        pendingRestore = bundle
                    case .failure(let error):
                        backupError = error
                    case nil:
                        break  // the user cancelled the panel
                    }
                } label: {
                    Label(
                        L(
                            "general.advanced.backup.restore",
                            "Restore from Backup…"
                        ),
                        systemImage: "square.and.arrow.down"
                    )
                }
                .settingsActionButton()
                HelpButton(
                    explanation: L(
                        "general.advanced.backup.restore.help",
                        "Replaces everything currently saved — "
                            + "your settings, every profile, and "
                            + "your color palettes — with what's "
                            + "in the chosen file. The versions "
                            + "being replaced go to the Trash. "
                            + "init.lua is never touched."
                    ),
                    subject: L(
                        "general.advanced.backup.restore",
                        "Restore from Backup…"
                    )
                )
            }
            Text(
                L(
                    "general.advanced.backup.restore.caption",
                    "Replaces your settings, profiles, and color "
                        + "palettes with what's in a backup file. "
                        + "Doesn't touch init.lua."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        // Built from the bundle it will apply, handed over by
        // `presenting:` rather than read from parent state in the
        // same tick (#843's shape, in the chrome that has it).
        //
        // Its own dialog rather than the shared `discardingEdits`
        // gate, for the reason `resetAllRow` gives: that gate only
        // fires while `isDirty`, and this must confirm every time.
        // The message names BOTH consequences — the saved data
        // replaced and the unsaved draft dropped — where Reset
        // All's names only the first.
        .confirmationDialog(
            L(
                "general.advanced.backup.restore.confirm.title",
                "Restore from this backup?"
            ),
            isPresented: restoreConfirmBinding,
            titleVisibility: .visible,
            presenting: pendingRestore
        ) { bundle in
            Button(
                L(
                    "general.advanced.backup.restore.confirm",
                    "Restore"
                ),
                role: .destructive
            ) {
                backupError = model.restoreBackup(bundle)
                pendingRestore = nil
            }
            Button(
                // `spaces.delete_confirm.cancel`, not
                // `discard.cancel`, for the reason and with the
                // accepted coupling `resetAllRow` documents —
                // stated there once rather than paraphrased
                // here, a paraphrase of it having already
                // shipped a wrong locale count.
                L("spaces.delete_confirm.cancel", "Cancel"),
                role: .cancel
            ) { pendingRestore = nil }
        } message: { _ in
            Text(
                L(
                    "general.advanced.backup.restore.confirm"
                        + ".message",
                    "This replaces your settings, every profile, "
                        + "and your color palettes with what's in "
                        + "the backup file — and discards any "
                        + "changes you haven't saved yet. The "
                        + "files being replaced go to the Trash. "
                        + "init.lua is never touched."
                )
            )
        }
    }

    /// The dialog is presented exactly while a bundle is waiting,
    /// so the two cannot disagree — one source of truth, not a
    /// Bool shadowing an Optional.
    private var restoreConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )
    }
}
