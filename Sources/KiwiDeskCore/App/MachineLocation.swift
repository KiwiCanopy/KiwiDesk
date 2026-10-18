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

    /// `directory`'s socket, or — where that path would pass
    /// `sun_path`'s limit, a long home's case — a short one in the
    /// per-user temp folder named by `directory`, which the app
    /// and the CLI derive alike.
    static func socket(in directory: URL) -> URL {
        let path = directory.appendingPathComponent(socketName)
        guard path.path.utf8.count >= socketPathLimit else { return path }
        return URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("KiwiDesk-\(digest(directory.path)).sock")
    }

    /// `sockaddr_un.sun_path`'s size, its NUL included.
    static let socketPathLimit = 104

    /// FNV-1a, stable across processes where `hashValue` is not.
    static func digest(_ text: String) -> String {
        var hash: UInt64 = 0xcbf2_9ce4_8422_2325
        for byte in text.utf8 {
            hash = (hash ^ UInt64(byte)) &* 0x100_0000_01b3
        }
        return String(hash, radix: 16)
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
    /// `config` into `machine` once and drops the old socket, so
    /// an update keeps the arrangement it quit with and the
    /// synced folder keeps none of it. A file the machine folder
    /// already holds wins, and the legacy copy is dropped. A file
    /// that fails to move stays, and the next launch retries it.
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
        guard !files.fileExists(atPath: new.path) else {
            try? files.removeItem(at: old)
            return
        }
        try? files.createDirectory(
            at: new.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? files.moveItem(at: old, to: new)
    }
}
