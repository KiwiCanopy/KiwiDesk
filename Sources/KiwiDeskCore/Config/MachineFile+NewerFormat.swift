import Foundation

extension MachineFile {
    /// The register's case for this file (`ConfigArtifact`).
    static var artifact: ConfigArtifact {
        switch destination {
        case .machine: return .machineConfig
        case .bindings: return .desktopBindings
        }
    }
}

extension MachineFileStore {
    /// The refusal owed before writing this file (#2325): `load()`
    /// reads a newer file as empty, so the latch asks here rather
    /// than trusting the decode (#2324).
    func newerFormat() -> NewerFormatOnDisk? {
        NewerFormatOnDisk.check(url, File.artifact, knows: File.currentFormat)
    }

    /// Throws `newerFormat()`; the write door's one line.
    func refuseNewer() throws {
        if let refusal = newerFormat() { throw refusal }
    }

    /// Keeps a corrupt file's copy before `save` overwrites it
    /// (#2324 ruling 13), in the backups beside it in the machine
    /// folder. Read as-is, as `load()` reads it.
    func keepCorrupt() {
        CorruptFile.keepBeforeOverwrite(
            url,
            as: File.self,
            migrating: false,
            in: url.deletingLastPathComponent()
                .appendingPathComponent(MigrationBackup.folderName)
        )
    }
}

extension ConfigArtifact {
    /// The file's name, nil for a folder (`profiles`, the backups);
    /// `NewerFormatLatchTests` holds it to `KiwiCore.url(of:)`.
    public var fileName: String? {
        switch self {
        case .guiConfig: return "gui.json"
        case .palettes: return "palettes.json"
        case .looks: return "looks.json"
        case .machineConfig: return MachineConfig.fileName
        case .desktopBindings: return DesktopBindingsFile.fileName
        case .profiles, .migrationBackups: return nil
        }
    }
}

extension NewerFormatOnDisk {
    /// The refused file's name, a profile's included.
    public var fileName: String {
        profile.map { "\($0).json" } ?? artifact.fileName ?? "\(artifact)"
    }
}
