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

    /// The files a pre-#2324 build kept in the config folder. A
    /// frozen spelling on the old side; the new side reads the
    /// same names, so they are taken from their owners.
    static let legacyNames = [
        CrashRecovery.autosaveName, CrashRecovery.sessionName,
        MigrationBackup.folderName,
    ]

    /// Moves every file under each `legacyNames` entry from
    /// `config` into `machine` and drops the old socket, so an
    /// update keeps the arrangement it quit with. A file the
    /// machine folder already holds wins and the legacy copy
    /// stays, as does a file that fails to move. Run once, by the
    /// launch that makes the machine folder.
    static func adoptLegacyFiles(from config: URL, into machine: URL) {
        guard
            config.resolvingSymlinksInPath().path
                != machine.resolvingSymlinksInPath().path
        else { return }
        for name in legacyNames {
            adopt(config.appendingPathComponent(name), as: name, in: machine)
        }
        // The old socket is stale once this build holds the lock.
        let stale = config.appendingPathComponent(socketName).path
        if !SocketServer.isLive(stale) {
            try? FileManager.default.removeItem(atPath: stale)
        }
    }

    /// One legacy entry, file or folder, moved file by file.
    private static func adopt(_ old: URL, as name: String, in machine: URL) {
        let files = FileManager.default
        var isFolder: ObjCBool = false
        guard files.fileExists(atPath: old.path, isDirectory: &isFolder)
        else { return }
        guard isFolder.boolValue else {
            move(old, to: machine.appendingPathComponent(name))
            return
        }
        let walk = files.enumerator(atPath: old.path)
        while let relative = walk?.nextObject() as? String {
            let source = old.appendingPathComponent(relative)
            var nested: ObjCBool = false
            files.fileExists(atPath: source.path, isDirectory: &nested)
            guard !nested.boolValue else { continue }
            move(
                source,
                to: machine.appendingPathComponent(name)
                    .appendingPathComponent(relative)
            )
        }
        // Empty once every file moved; a failed one keeps it.
        if (try? files.subpathsOfDirectory(atPath: old.path))?
            .allSatisfy({ path in
                var dir: ObjCBool = false
                files.fileExists(
                    atPath: old.appendingPathComponent(path).path,
                    isDirectory: &dir
                )
                return dir.boolValue
            }) == true
        {
            try? files.removeItem(at: old)
        }
    }

    private static func move(_ old: URL, to new: URL) {
        let files = FileManager.default
        // A copy already here wins; the legacy one stays, since a
        // Mac still on an older build may share the folder.
        guard !files.fileExists(atPath: new.path) else { return }
        try? files.createDirectory(
            at: new.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? files.moveItem(at: old, to: new)
    }
}
