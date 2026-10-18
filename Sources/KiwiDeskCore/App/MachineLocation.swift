import Foundation

/// Where this Mac's own state lives: the socket, the instance
/// lock, the arrangement snapshots and the migration copies
/// (#2324). It never follows the config folder, which a user may
/// sync to other Macs — every file here means something on this
/// machine only.
///
/// Read by every process half: the app's core, the CLI, the
/// service and `main.swift`, which takes the lock before any
/// config is read.
public enum MachineLocation {
    /// `~/Library/Application Support/KiwiDesk/`.
    public static var directory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/KiwiDesk"
            )
    }

    public static var socketPath: String {
        socket(in: directory).path
    }

    public static var lockPath: String {
        lock(in: directory).path
    }

    static func socket(in directory: URL) -> URL {
        directory.appendingPathComponent(socketName)
    }

    static func lock(in directory: URL) -> URL {
        directory.appendingPathComponent(lockName)
    }

    static let socketName = "KiwiDesk.sock"
    static let lockName = "KiwiDesk.lock"

    /// Where builds before #2324 kept the lock: a build updated
    /// while an older one still runs must not start beside it.
    public static var legacyLockPath: String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KiwiDesk")
            .appendingPathComponent(lockName).path
    }

    /// The files a pre-#2324 build kept in the config folder.
    static let legacyNames = [
        ".state_snapshot", ".session_snapshot",
        MigrationBackup.folderName,
    ]

    /// Moves each `legacyNames` file from `config` into `machine`
    /// once, so an update keeps the arrangement it quit with, and
    /// drops the old socket. A file the machine folder already
    /// holds stays where it is.
    static func adoptLegacyFiles(from config: URL, into machine: URL) {
        let files = FileManager.default
        guard
            config.resolvingSymlinksInPath().path
                != machine.resolvingSymlinksInPath().path
        else { return }
        for name in legacyNames {
            let old = config.appendingPathComponent(name)
            let new = machine.appendingPathComponent(name)
            guard files.fileExists(atPath: old.path),
                !files.fileExists(atPath: new.path)
            else { continue }
            try? files.moveItem(at: old, to: new)
        }
        // The old socket is stale once this build holds the lock.
        let stale = socket(in: config).path
        if !SocketServer.isLive(stale) {
            try? files.removeItem(atPath: stale)
        }
    }
}
