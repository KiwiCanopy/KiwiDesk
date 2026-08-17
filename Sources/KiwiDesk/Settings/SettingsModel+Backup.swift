import AppKit
import KiwiDeskCore

/// Export and restore a whole setup from Settings (#606).
///
/// The panels live here rather than in the view because they are
/// modal and synchronous: `runModal()` blocks, and a `body` is not
/// where a blocking call belongs.
extension SettingsModel {
    /// Core's one palette store, never a second over the same path
    /// — `KiwiCore.paletteLibrary` says why.
    ///
    /// Housed here rather than on the class because a computed
    /// property can live in an extension and `SettingsModel.swift`
    /// sits permanently against §2.1's ceiling; a stored property
    /// has no such choice.
    var paletteStore: PaletteStore { core.paletteLibrary }

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
        // Refuse BEFORE the panel, not after. This feature's own
        // read/restore split exists on exactly this principle —
        // "a dialog for a restore that will fail on the first read
        // is a dialog that should never have opened" — and the
        // check needs no file panel to answer, so asking the user
        // to pick a folder and type a filename first was the same
        // mistake one surface over (`code-reviewer`, 2026-08-17).
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
            let bundle = try core.readBackup(at: url)
            // **Refuse here, not after the confirm.** This is the
            // one place both the decoded bundle and the destination
            // are in hand, and `isGuiManaged` needs no dialog to
            // answer — so asking the user to confirm replacing
            // everything and then refusing was the same mistake
            // `exportBackup` was corrected for one function up
            // (`architect-reviewer`, 2026-08-17). Core keeps its
            // own throw as the backstop.
            if bundle.config != nil, !core.isGuiManaged {
                return .failure(.luaOwnsThisMac)
            }
            return .success(bundle)
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
    /// Returns the failure, or nil on success — the caller shows
    /// the alert.
    ///
    /// A write that fails AFTER the originals are in the Trash is
    /// the one failure class the pre-flight read cannot catch, so
    /// it is the one that must not be swallowed. `reload()` runs
    /// either way: the files on disk changed even on the failing
    /// path, so an editor still describing the old ones would be
    /// lying about what is there.
    func restoreBackup(_ bundle: SetupBundle) -> SetupBundleError? {
        defer { reload() }
        do {
            let outcome = try core.restoreSetup(
                from: bundle,
                trash: KiwiCore.moveToTrash
            )
            // A partial restore is not a failure and must not read
            // as one — but it must not read as unqualified success
            // either, which is what returning nil here used to do.
            lastRestoreOutcome = outcome.isClean ? nil : outcome
            return nil
        } catch {
            return error
        }
    }
}
