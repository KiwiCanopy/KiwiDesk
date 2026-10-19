import AppKit
import KiwiDeskCore

/// The folder as Finder names it, for the row and the sheet.
enum SyncFolderDisplay {
    /// "iCloud Drive ▸ KiwiDesk", or "~ ▸ Dotfiles ▸ KiwiDesk".
    static func path(_ url: URL) -> String {
        let files = FileManager.default
        let parts =
            files.componentsToDisplay(forPath: url.path)
            ?? [url.lastPathComponent]
        let drive = SyncFolderLocation.iCloudDrive
        if url.path.hasPrefix(drive.path),
            let index = parts.firstIndex(
                of: files.displayName(atPath: drive.path)
            )
        {
            return parts[index...].joined(separator: " ▸ ")
        }
        let home =
            files.componentsToDisplay(
                forPath: files.homeDirectoryForCurrentUser.path
            ) ?? []
        if !home.isEmpty, parts.starts(with: home) {
            return (["~"] + parts.dropFirst(home.count))
                .joined(separator: " ▸ ")
        }
        return parts.joined(separator: " ▸ ")
    }
}

/// Compare and Copy's doors into Core (#2324 slice 2).
extension SettingsModel {
    /// This Mac's sync folder, kept in the model's preferences.
    var syncFolder: URL? {
        get { SyncFolderLocation.stored(in: preferences) }
        set { SyncFolderLocation.store(newValue, in: preferences) }
    }

    /// Why `folder` refuses both directions, if it does.
    func syncFolderRefusal(_ folder: URL) -> SyncRefusal? {
        core.syncFolderRefusal(folder)
    }

    func compareSync(with folder: URL) -> SyncComparison {
        core.compareSync(with: folder)
    }

    /// Saves the draft first where it holds edits, then copies this
    /// Mac's setup into `folder`. A Save that does not land copies
    /// nothing and answers nil, its own surface saying why.
    func keepThisMacsSetup(in folder: URL) -> SyncRefusal? {
        if isDirty {
            guard syncSaveBlockedReason == nil else { return nil }
            performPrimarySave()
            guard !isDirty else { return nil }
        }
        do {
            try core.keepThisMacsSetup(
                in: folder,
                trash: KiwiCore.moveToTrash
            )
            return nil
        } catch {
            return error
        }
    }

    /// Replaces this Mac's setup with `folder`'s. Reloads — which
    /// drops the draft, as the sheet said — only once this Mac's
    /// setup was touched; a refusal before that keeps the edits.
    func keepFoldersSetup(from folder: URL) -> SyncRefusal? {
        do {
            let outcome = try core.withUserMotion {
                () throws(SyncRefusal) in
                try core.keepFoldersSetup(
                    from: folder,
                    trash: KiwiCore.moveToTrash
                )
            }
            reload()
            lastRestoreOutcome = outcome.isClean ? nil : outcome
            return nil
        } catch {
            if case .copy(.couldNotWrite) = error { reload() }
            return error
        }
    }

    /// Why Save and Keep This Mac's cannot save first, if it
    /// cannot: Save is blocked, or wants a name it has to ask for.
    var syncSaveBlockedReason: String? {
        if let reason = primarySaveBlockedReason { return reason }
        guard primarySaveAction == .saveAsNewProfile else { return nil }
        return L(
            "general.sync.save_needs_name",
            "A new profile needs a name first. Name it, then copy."
        )
    }
}
