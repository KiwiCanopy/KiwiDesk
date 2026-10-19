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

    /// Keeps a corrupt file's copy in `backups` before `save`
    /// overwrites it (#2324 ruling 13). Read as-is, as `load()`
    /// reads it.
    func keepCorrupt(in backups: URL?) {
        CorruptFile.keepBeforeOverwrite(
            url,
            as: File.self,
            migrating: false,
            in: backups
        )
    }
}

extension GuiConfigStore {
    /// The refusal `saveIncludingBindings`, which every Settings
    /// Save ends in, owes (#2325): `gui.json` or either machine
    /// file a newer build wrote — the one list the Settings latch
    /// reads too (`KiwiCore.guiConfigWriteLatch`).
    public func newerFormat() -> NewerFormatOnDisk? {
        sidecarNewerFormat()
            ?? machine.newerFormat()
            ?? bindingsFile.newerFormat()
    }

    /// `gui.json` alone, a newer one.
    func sidecarNewerFormat() -> NewerFormatOnDisk? {
        NewerFormatOnDisk.check(
            url,
            .guiConfig,
            knows: GuiConfig.currentFormat
        )
    }
}
