import Foundation

/// The pieces `KiwiCore.init` builds before it can call
/// `bootstrapCoreServices()`.
///
/// Split out because a class's designated initializer must live
/// in the main declaration, so `KiwiCore.swift` is the one file
/// that cannot shed weight by moving a method — it is a property
/// bag plus this one function, and it reached §2.1's 350-line
/// ceiling exactly (#836's flag was the line that crossed it).
/// Static helpers can live in an extension; the `init` calling
/// them cannot.
///
/// Each helper takes the resolved directory rather than reading
/// it back off `self`: the initializer needs them all before the
/// stored properties are assigned.
extension KiwiCore {
    /// `~/.config/KiwiDesk/` unless the caller names its own.
    /// `makeTestCore` always names one — a bare `KiwiCore()`
    /// would otherwise read and write the developer's live
    /// config, which is half of what `MachineTouchTests` pins.
    static func resolveConfigDirectory(_ override: URL?) -> URL {
        override
            ?? FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/KiwiDesk")
    }

    /// The config and machine folders. The first launch with a
    /// machine folder is handed this Mac's files a pre-#2324 build
    /// left in the config folder — that launch alone, marked by
    /// `MachineLocation.adoptedMarker`, since a Mac still on an
    /// older build may share the folder later and `main.swift`'s
    /// lock makes the folder before any core.
    /// `makeTestCore` names both, so no test reaches `~/Library`
    /// (`CoreInitPathTests`).
    static func resolveDirectories(
        _ config: URL?,
        _ machine: URL?
    ) -> (config: URL, machine: URL) {
        let directory = resolveConfigDirectory(config)
        let machine = machine ?? MachineLocation.directory
        let files = FileManager.default
        try? files.createDirectory(
            at: machine,
            withIntermediateDirectories: true
        )
        let marker = machine.appendingPathComponent(
            MachineLocation.adoptedMarker
        )
        if !files.fileExists(atPath: marker.path) {
            MachineLocation.adoptLegacyFiles(from: directory, into: machine)
            files.createFile(atPath: marker.path, contents: nil)
        }
        return (directory, machine)
    }

    static func makeSocketServer(in machine: URL) -> SocketServer {
        SocketServer(path: MachineLocation.socket(in: machine).path)
    }

    static func makeProfileManager(
        _ directory: URL,
        _ machine: URL
    ) -> ProfileManager {
        let manager = ProfileManager(
            directory: directory.appendingPathComponent("profiles")
        )
        manager.migrationBackups = migrationBackups(in: machine)
        return manager
    }

    /// The one home of the migration copies (#1880), in the
    /// machine folder since #2324.
    static func migrationBackups(in machine: URL) -> URL {
        machine.appendingPathComponent(MigrationBackup.folderName)
    }
}
