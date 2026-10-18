import Foundation

/// The files a KiwiDesk setup is made of, and the one policy for
/// removing them.
///
/// Two paths clear config artifacts — `resetAllSettings` and
/// `restoreSetup` — and before this type they each carried their
/// own copy of the same list and the same trash-then-delete
/// policy. Both reviewers called it: not the small readable
/// duplication §2.4 protects, but a **failure-mode policy** whose
/// copies can diverge, and they already had (different log
/// prefixes, one inlined and one extracted, only one callable).
public enum ConfigArtifact: CaseIterable, Sendable {
    /// The GUI's settings sidecar.
    case guiConfig
    /// Every saved profile.
    case profiles
    /// The saved colour-palette library.
    case palettes
    /// The saved look library (#1684).
    case looks
    /// The copies a migration keeps of the files it rewrote
    /// (#1880, `MigrationBackup`).
    case migrationBackups
    /// This Mac's `GuiConfig` leaves (#2324, `MachineConfig`).
    case machineConfig
    /// The Desktop bindings (#2324 ruling 12,
    /// `DesktopBindingsFile`): kept on this Mac, carried by a
    /// backup as the bundle's own field.
    case desktopBindings

    /// What a backup carries.
    ///
    /// **This is the register `SetupBundle` is checked against**,
    /// and the direction no other guard can see: `SetupBundleTests`
    /// asserts the bundle's own top-level keys, so a field ADDED to
    /// the bundle has to argue for itself — but a new artifact that
    /// never joined the bundle is invisible everywhere, and its
    /// symptom is a user moving Macs and silently losing whatever
    /// it held. `palettes.json` nearly was that symptom.
    ///
    /// So a new file KiwiDesk keeps — in the config folder or in
    /// `MachineLocation`'s — adds a case here and answers this
    /// property in the same change set; `url(of:)` says where.
    /// `SetupBundleArtifactTests` holds the two together.
    public var travelsInABackup: Bool {
        switch self {
        case .guiConfig, .profiles, .palettes, .looks: return true
        case .desktopBindings: return true
        case .migrationBackups, .machineConfig: return false
        }
    }

    /// Whether the file lives in `MachineLocation`'s folder rather
    /// than the config folder; `url(of:)` follows it, and such a
    /// file never travels (`SetupBundleArtifactTests`).
    public var livesOnThisMac: Bool {
        switch self {
        case .guiConfig, .profiles, .palettes, .looks: return false
        case .migrationBackups, .machineConfig, .desktopBindings:
            return true
        }
    }

    /// Why anything answering `false` to `travelsInABackup` stays
    /// behind: an exclusion is a decision on record, never an
    /// omission (`SetupBundleArtifactTests`).
    public var leftBehindBecause: String? {
        switch self {
        case .guiConfig, .profiles, .palettes, .looks, .desktopBindings:
            return nil
        case .migrationBackups:
            return "a copy of this Mac's files at an older format, "
                + "for a downgrade here; the backup carries the "
                + "current files"
        case .machineConfig:
            return "which Space each of this Mac's Desktops was "
                + "showing; another Mac's Desktops are not these"
        }
    }
}

extension KiwiCore {
    /// Where a migrated rewrite keeps the original (#1880).
    var migrationBackups: URL {
        Self.migrationBackups(in: machineDirectory)
    }

    /// Where each artifact lives.
    func url(of artifact: ConfigArtifact) -> URL {
        switch artifact {
        case .guiConfig: return guiConfigStore.url
        case .profiles: return profiles.directory
        case .palettes: return paletteLibrary.url
        case .looks: return lookLibrary.url
        case .migrationBackups: return migrationBackups
        case .machineConfig: return guiConfigStore.machine.url
        case .desktopBindings: return guiConfigStore.bindingsFile.url
        }
    }

    /// Removes `artifacts`, preferring the Trash.
    ///
    /// A failed trash falls back to a hard delete, and that is not
    /// a courtesy detail: a surviving `gui.json` flips the next
    /// reload back onto the OLD sidecar and turns a confirmed wipe
    /// or replace into a silent no-op, which is strictly worse
    /// than skipping the Trash. Returns whether everything asked
    /// for is actually gone.
    ///
    /// `trash` has no default on purpose — the compiler forces
    /// every caller to choose. A defaulted parameter once let a
    /// bare test call fill the developer's real Trash with zero
    /// red; do not re-add one.
    @discardableResult
    func discardArtifacts(
        _ artifacts: [ConfigArtifact],
        reason: String,
        trash: (URL) throws -> Void
    ) -> Bool {
        let files = FileManager.default
        var cleared = true
        // Both shortcut marks vouch for rows in this file, so a
        // discarded sidecar offers every Desktop and generation again.
        if artifacts.contains(.guiConfig) {
            desktopMemory.writeShortcutMark(0)
            desktopMemory.writeDefaultsGeneration(0)
            desktopMemory.shortcutTopUpDeclined = 0
        }
        for url in artifacts.map(url(of:))
        where files.fileExists(atPath: url.path) {
            do {
                try trash(url)
            } catch {
                onLog(
                    "\(reason): could not trash "
                        + "\(url.lastPathComponent) (\(error)); "
                        + "deleting instead"
                )
                do {
                    try files.removeItem(at: url)
                } catch {
                    onLog(
                        "\(reason): could not delete "
                            + "\(url.lastPathComponent): \(error)"
                    )
                    cleared = false
                }
            }
        }
        return cleared
    }
}
