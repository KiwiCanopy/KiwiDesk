import KiwiDeskCore
import SwiftUI

/// General ▸ Files & Reset: backup export and restore actions (#606).
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
                    + "looks, in one file. init.lua is left out "
                    + "unless you include it."
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
            ),
            helpSubject: SettingsCatalog.general.generalAdvanced
                .children.exportBackup.text
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
                    + "init.lua only if you ask."
            ),
            help: L(
                "general.advanced.backup.restore.help",
                "Replaces everything currently saved — "
                    + "your settings, every profile, and "
                    + "your color palettes and looks — "
                    + "with what's "
                    + "in the chosen file. The versions "
                    + "being replaced go to the Trash. If the "
                    + "backup includes an init.lua, you choose "
                    + "whether to restore it too; otherwise "
                    + "yours stays as it is."
            ),
            helpSubject: SettingsCatalog.general.generalAdvanced
                .children.restoreBackup.text
        ) {
            Button(
                L("general.advanced.backup.restore.short", "Restore…")
            ) {
                switch model.readBackupToRestore() {
                case .success(let bundle):
                    confirmRestore(bundle)
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
    }

    /// Asks every time, never through `discardingEdits`, which
    /// fires only while dirty: the message names both
    /// consequences, saved data replaced and the draft dropped.
    private func confirmRestore(_ bundle: SetupBundle) {
        // The Settings window, key again once the open panel closes.
        guard let window = NSApp.keyWindow ?? NSApp.mainWindow else {
            return
        }
        RestoreConfirm.ask(
            model.core.restoreChoices(for: bundle),
            over: window
        ) { replacingInitLua in
            backupError = model.restoreBackup(
                bundle,
                replacingInitLua: replacingInitLua
            )
        }
    }
}
