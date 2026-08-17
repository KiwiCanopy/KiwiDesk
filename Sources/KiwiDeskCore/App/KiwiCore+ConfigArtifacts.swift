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
public enum ConfigArtifact: CaseIterable {
    /// The GUI's settings sidecar.
    case guiConfig
    /// Every saved profile.
    case profiles
    /// The saved colour-palette library.
    case palettes

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
    /// So a new file under `~/.config/KiwiDesk` adds a case here
    /// and answers this property in the same change set.
    /// `SetupBundleArtifactTests` holds the two together.
    public var travelsInABackup: Bool {
        switch self {
        case .guiConfig, .profiles, .palettes: return true
        }
    }

    /// Why anything answering `false` to `travelsInABackup` stays
    /// behind. Empty today, and kept as a declared slot rather
    /// than dropped: its absence is what would make a future
    /// exclusion look like an omission instead of a decision.
    public var leftBehindBecause: String? {
        switch self {
        case .guiConfig, .profiles, .palettes: return nil
        }
    }
}

extension KiwiCore {
    /// Where each artifact lives.
    func url(of artifact: ConfigArtifact) -> URL {
        switch artifact {
        case .guiConfig: return guiConfigStore.url
        case .profiles: return profiles.directory
        case .palettes: return paletteLibrary.url
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
