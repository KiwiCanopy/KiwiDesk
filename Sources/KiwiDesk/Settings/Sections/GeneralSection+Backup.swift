import KiwiDeskCore
import SwiftUI

/// General ▸ Advanced: backup export and restore actions (#606).
///
/// Follows ascending severity ordering defined in `GeneralSection+Reset`.
extension GeneralSection {
    // MARK: - Export (read-only, above the ladder)

    var exportBackupRow: some View {
        SettingsActionRow(
            title: L("general.advanced.backup.row", "KiwiDesk backup"),
            caption: L(
                "general.advanced.backup.export.caption",
                "Your settings, profiles, color palettes and "
                    + "looks, in one file. Doesn't include "
                    + "init.lua."
            ),
            // A concept, not a live fact, which is what
            // `ui-patterns.md` gives the `?`. It also defuses a
            // real misread: "KiwiDesk Backup" pattern-matches
            // "iCloud Backup", and KiwiDesk keeps none.
            help: L(
                "general.advanced.backup.export.help",
                "A one-time snapshot, saved to a file you "
                    + "choose. KiwiDesk doesn't keep "
                    + "backups on its own — export again "
                    + "whenever you want an up-to-date "
                    + "copy."
            )
        ) {
            Button(advancedExportLabel) {
                backupError = model.exportBackup()
            }
            .settingsActionButton()
            .accessibilityLabel(
                SettingsCatalog.general.generalAdvanced.children
                    .exportBackup.text
            )
        }
        .searchAnchored(
            SettingsCatalog.general.generalAdvanced.children
                .exportBackup
        )
    }

    // MARK: - Restore (the ladder's final rung)

    var restoreBackupRow: some View {
        SettingsActionRow(
            title: L(
                "general.advanced.backup.restore.row",
                "Restore from backup"
            ),
            caption: L(
                "general.advanced.backup.restore.caption",
                "Replaces your settings, profiles, color "
                    + "palettes and looks with a backup's. "
                    + "Doesn't touch init.lua."
            ),
            help: L(
                "general.advanced.backup.restore.help",
                "Replaces everything currently saved — "
                    + "your settings, every profile, and "
                    + "your color palettes and looks — "
                    + "with what's "
                    + "in the chosen file. The versions "
                    + "being replaced go to the Trash. "
                    + "init.lua is never touched."
            )
        ) {
            Button(
                L("general.advanced.backup.restore.short", "Restore…")
            ) {
                switch model.readBackupToRestore() {
                case .success(let bundle):
                    pendingRestore = bundle
                case .failure(let error):
                    backupError = error
                case nil:
                    break  // the user cancelled the panel
                }
            }
            .settingsActionButton()
            .accessibilityLabel(
                SettingsCatalog.general.generalAdvanced.children
                    .restoreBackup.text
            )
        }
        .searchAnchored(
            SettingsCatalog.general.generalAdvanced.children
                .restoreBackup
        )
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
                        + "and your color palettes and looks with "
                        + "what's in "
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
