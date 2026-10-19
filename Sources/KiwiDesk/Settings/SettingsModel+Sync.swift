import AppKit
import KiwiDeskCore

/// A folder as KiwiDesk names it, for the row and the sheet:
/// "iCloud Drive ▸ KiwiDesk" or "~ ▸ .config ▸ KiwiDesk", each
/// component in Finder's localized name. Never follows a symlink, so
/// a dotfiles link stays as the user named it.
enum SyncFolderDisplay {
    /// `name` turns a path into its display name; tests inject it.
    static func path(
        _ url: URL,
        name: (String) -> String = FileManager.default.displayName(atPath:)
    ) -> String {
        let path = url.standardizedFileURL.path
        let drive = SyncFolderLocation.iCloudDrive.standardizedFileURL.path
        let home = FileManager.default.homeDirectoryForCurrentUser
            .standardizedFileURL.path
        if let rest = remainder(of: path, under: drive, name: name) {
            return ([name(drive)] + rest).joined(separator: " ▸ ")
        }
        if let rest = remainder(of: path, under: home, name: name) {
            return (["~"] + rest).joined(separator: " ▸ ")
        }
        return remainder(of: path, under: "", name: name)?
            .joined(separator: " ▸ ") ?? path
    }

    /// The display names of the folders below `root`, each named from
    /// its own unresolved prefix, or nil where `path` is not in it.
    private static func remainder(
        of path: String,
        under root: String,
        name: (String) -> String
    ) -> [String]? {
        guard path == root || path.hasPrefix(root + "/") else { return nil }
        var prefix = root
        return path.dropFirst(root.count).split(separator: "/").map {
            prefix += "/" + $0
            return name(prefix)
        }
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
