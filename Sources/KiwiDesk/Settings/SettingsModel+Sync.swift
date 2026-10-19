import AppKit
import KiwiDeskCore

/// The sync folder, remembered on this Mac alone and never in the
/// folder (#2324 ruling 14): a per-Mac preference in the app's
/// defaults, like the Settings mode.
enum SyncFolderPreference {
    static let key = "general.syncFolder"

    static var stored: URL? {
        get {
            UserDefaults.standard.string(forKey: key)
                .map { URL(fileURLWithPath: $0, isDirectory: true) }
        }
        set { UserDefaults.standard.set(newValue?.path, forKey: key) }
    }

    /// iCloud Drive's own folder; absent while Drive is off.
    static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Mobile Documents/com~apple~CloudDocs",
                isDirectory: true
            )
    }

    static var iCloudDriveIsOn: Bool {
        FileManager.default.fileExists(atPath: iCloudDrive.path)
    }

    /// The folder the iCloud Drive pick keeps the setup in.
    static var iCloudFolder: URL {
        iCloudDrive.appendingPathComponent("KiwiDesk", isDirectory: true)
    }

    static func isICloudFolder(_ url: URL) -> Bool {
        url.standardizedFileURL == iCloudFolder.standardizedFileURL
    }

    /// The folder as Finder names it: "iCloud Drive ▸ KiwiDesk".
    static func displayPath(_ url: URL) -> String {
        let parts =
            FileManager.default.componentsToDisplay(
                forPath: url.path
            ) ?? [url.lastPathComponent]
        let home =
            FileManager.default.componentsToDisplay(
                forPath: FileManager.default.homeDirectoryForCurrentUser.path
            ) ?? []
        if isICloudFolder(url) || url.path.hasPrefix(iCloudDrive.path) {
            let drive = FileManager.default.displayName(
                atPath: iCloudDrive.path
            )
            if let index = parts.firstIndex(of: drive) {
                return parts[index...].joined(separator: " ▸ ")
            }
        }
        if parts.starts(with: home) {
            return (["~"] + parts.dropFirst(home.count))
                .joined(separator: " ▸ ")
        }
        return parts.joined(separator: " ▸ ")
    }
}

/// Compare and Copy's doors into Core (#2324 slice 2).
extension SettingsModel {
    /// Why `folder` refuses both directions, if it does.
    func syncFolderRefusal(_ folder: URL) -> SyncRefusal? {
        core.syncFolderRefusal(folder)
    }

    func compareSync(with folder: URL) -> SyncComparison {
        core.compareSync(with: folder)
    }

    /// Copies this Mac's setup into `folder`; nothing on this Mac
    /// changes, so nothing reloads.
    func keepThisMacsSetup(in folder: URL) -> SyncRefusal? {
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

    /// Replaces this Mac's setup with `folder`'s. Drops the draft
    /// through `reload()`, as a restore does: the sheet said so.
    func keepFoldersSetup(from folder: URL) -> SyncRefusal? {
        defer { reload() }
        do {
            let outcome = try core.withUserMotion {
                () throws(SyncRefusal) in
                try core.keepFoldersSetup(
                    from: folder,
                    trash: KiwiCore.moveToTrash
                )
            }
            lastRestoreOutcome = outcome.isClean ? nil : outcome
            return nil
        } catch {
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
            "Save needs a name for a new profile. Save first, "
                + "then copy."
        )
    }
}
