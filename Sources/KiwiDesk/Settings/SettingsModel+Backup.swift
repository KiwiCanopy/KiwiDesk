import AppKit
import KiwiDeskCore

/// Export and restore whole setup from Settings (#606).
extension SettingsModel {
    /// Shared palette store (`KiwiCore.paletteLibrary`).
    var paletteStore: PaletteStore { core.paletteLibrary }

    /// Suggested filename with ISO date for backup exports.
    var suggestedBackupName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "KiwiDesk Backup \(formatter.string(from: Date()))"
            + ".json"
    }

    /// Writes a backup archive to the user-selected save path.
    /// Returns the failure rather than swallowing it: a backup
    /// that silently did not happen is worse than one that says
    /// so. Refuses BEFORE the panel — a dialog for an export that
    /// will fail on the first read should never open
    /// (`code-reviewer`, 2026-08-17).
    func exportBackup() -> SetupBundleError? {
        if core.guiConfigStore.exists,
            core.guiConfigStore.load() == nil
        {
            return .unreadableSettings
        }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = suggestedBackupName
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        do {
            try core.writeBackup(to: url)
            return nil
        } catch {
            return error
        }
    }

    /// Prompts for a backup file and reads it without applying
    /// (`architect-reviewer`, 2026-08-17).
    func readBackupToRestore() -> Result<
        SetupBundle, SetupBundleError
    >? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else {
            return nil
        }
        do {
            let bundle = try core.readBackup(at: url)
            // Refuse HERE, not after the confirm: both the
            // decoded bundle and the destination are in hand, and
            // `isGuiManaged` needs no dialog to answer
            // (`architect-reviewer`, 2026-08-17).
            if bundle.config != nil, !core.isGuiManaged {
                return .failure(.luaOwnsThisMac)
            }
            return .success(bundle)
        } catch {
            return .failure(error)
        }
    }

    /// Applies a confirmed backup. A write failing AFTER the
    /// originals are in the Trash is the one class the pre-flight
    /// read cannot catch, so it must not be swallowed — and
    /// `reload()` runs either way: the files changed even on the
    /// failing path, and an editor describing the old ones would
    /// be lying.
    func restoreBackup(_ bundle: SetupBundle) -> SetupBundleError? {
        defer { reload() }
        do {
            let outcome = try core.restoreSetup(
                from: bundle,
                trash: KiwiCore.moveToTrash
            )
            // A partial restore is not a failure, but must not
            // read as unqualified success either.
            lastRestoreOutcome = outcome.isClean ? nil : outcome
            return nil
        } catch {
            return error
        }
    }
}
