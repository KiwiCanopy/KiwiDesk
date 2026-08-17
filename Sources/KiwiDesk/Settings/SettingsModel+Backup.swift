import AppKit
import KiwiDeskCore

/// Export and restore a whole setup from Settings (#606).
///
/// The panels live here rather than in the view because they are
/// modal and synchronous: `runModal()` blocks, and a `body` is not
/// where a blocking call belongs.
extension SettingsModel {
    /// A filename a user will recognise a year later in a Downloads
    /// folder, dated so two backups never collide silently.
    ///
    /// The date is ISO-ordered on purpose — it sorts correctly in
    /// Finder, which a localized date does not.
    var suggestedBackupName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return "KiwiDesk Backup \(formatter.string(from: Date()))"
            + ".json"
    }

    /// Writes a backup wherever the user points the save panel.
    ///
    /// Returns the failure rather than swallowing it: the palette
    /// shelf's `try?` is the shape this deliberately does not
    /// copy — a backup that silently did not happen is worse than
    /// one that says so, because the user walks away believing
    /// they have it.
    func exportBackup() -> SetupBundleError? {
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

    /// Asks for a backup file and reads it — **without applying
    /// anything**.
    ///
    /// Reading before confirming is the point: the user is about
    /// to be asked to replace everything they have, and a dialog
    /// for a restore that will fail on the first read is a dialog
    /// that should never have opened.
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
            return .success(try core.readBackup(at: url))
        } catch {
            return .failure(error)
        }
    }

    /// Applies a backup the user has confirmed.
    ///
    /// `reload()` after, exactly as the reset hatch does: the
    /// staged draft edited the state that just went to the Trash,
    /// so keeping it would leave the editor describing files that
    /// no longer exist.
    func restoreBackup(_ bundle: SetupBundle) {
        core.restoreSetup(
            from: bundle,
            trash: KiwiCore.moveToTrash
        )
        reload()
    }
}
