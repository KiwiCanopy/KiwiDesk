import Foundation

/// Where this Mac's sync folder is, remembered on this Mac alone and
/// never in the folder (#2324 ruling 14): a per-Mac preference in
/// the app's defaults, beside which slice 3's following will sit.
public enum SyncFolderLocation {
    static let key = "general.syncFolder"

    /// The folder last chosen in `defaults`, nil while none is.
    public static func stored(in defaults: UserDefaults) -> URL? {
        defaults.string(forKey: key)
            .map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    /// Remembers `folder` in `defaults`; nil forgets it.
    public static func store(_ folder: URL?, in defaults: UserDefaults) {
        defaults.set(folder?.path, forKey: key)
    }

    static let followsKey = "general.syncFollows"

    /// Whether this Mac keeps its folder in step on its own
    /// (#2324 ruling 15): on once a folder is chosen, until the
    /// user switches it off.
    public static func follows(in defaults: UserDefaults) -> Bool {
        defaults.object(forKey: followsKey) as? Bool ?? true
    }

    public static func storeFollows(_ on: Bool, in defaults: UserDefaults) {
        defaults.set(on, forKey: followsKey)
    }

    /// The folder to keep in step, nil while none is chosen or the
    /// switch is off.
    public static func followed(in defaults: UserDefaults) -> URL? {
        follows(in: defaults) ? stored(in: defaults) : nil
    }

    /// iCloud Drive's own folder; absent while Drive is off.
    public static var iCloudDrive: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Mobile Documents/com~apple~CloudDocs",
                isDirectory: true
            )
    }

    public static var iCloudDriveIsOn: Bool {
        FileManager.default.fileExists(atPath: iCloudDrive.path)
    }

    /// The folder the iCloud Drive pick keeps the setup in.
    public static var iCloudFolder: URL {
        iCloudDrive.appendingPathComponent("KiwiDesk", isDirectory: true)
    }

    public static func isICloudFolder(_ url: URL) -> Bool {
        url.standardizedFileURL == iCloudFolder.standardizedFileURL
    }

    /// Whether `url` lies inside iCloud Drive.
    static func isInICloudDrive(_ url: URL) -> Bool {
        url.standardizedFileURL.path.hasPrefix(
            iCloudDrive.standardizedFileURL.path
        )
    }
}
