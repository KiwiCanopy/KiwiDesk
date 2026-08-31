import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: backup export and restore actions (#606).
///
/// Follows ascending severity ordering defined in `GeneralSection+Reset`.
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
        // `presenting:` (#843's shape). Its own dialog rather than
        // the shared `discardingEdits` gate: that gate fires only
        // while `isDirty`, and this must confirm every time — the
        // message names BOTH consequences, saved data replaced and
        // unsaved draft dropped.
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

    /// Presents confirmation dialog while pending restore bundle exists.
    private var restoreConfirmBinding: Binding<Bool> {
        Binding(
            get: { pendingRestore != nil },
            set: { if !$0 { pendingRestore = nil } }
        )
    }
}
