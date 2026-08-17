import KiwiDeskCore

/// The GUI's half of the backup seam (#96): Core names the
/// condition, this renders the sentence.
///
/// Core throws `SetupBundleError` cases — structure a test can
/// match and a locale can translate. A pre-rendered English string
/// built in Core would be invisible to `scripts/extract-keys` and
/// untranslatable in every catalog, which is the defect
/// `core-boundaries.md` exists to prevent.
@MainActor
enum SetupBackupText {
    /// Why a restore could not start, in one sentence.
    ///
    /// Total by construction — a new `SetupBundleError` case owes
    /// an arm here, and the compiler asks for it.
    static func sentence(for error: SetupBundleError) -> String {
        switch error {
        case .unreadable:
            return L(
                "general.advanced.backup.error.unreadable",
                "That file couldn't be opened. It may have been "
                    + "moved, renamed, or deleted."
            )
        case .notABackup:
            return L(
                "general.advanced.backup.error.not_a_backup",
                "That file isn't a KiwiDesk backup."
            )
        case .newerFormat:
            // The two version numbers are deliberately NOT
            // interpolated. They name an internal format, not the
            // app version a user could act on, so the sentence
            // that helps is the one telling them what to do.
            return L(
                "general.advanced.backup.error.newer",
                "That backup was made by a newer version of "
                    + "KiwiDesk. Update KiwiDesk, then try again."
            )
        case .empty:
            return L(
                "general.advanced.backup.error.empty",
                "That backup is empty — there's nothing in it to "
                    + "restore."
            )
        case .couldNotWrite(let name):
            return L(
                "general.advanced.backup.error.write_failed",
                "KiwiDesk couldn't write “%1$@”. Try somewhere "
                    + "else, like your Desktop.",
                name
            )
        }
    }

    /// The alert's title — one for every case, because a title
    /// that changes per cause reads as five different failures of
    /// five different features.
    static func title(for error: SetupBundleError) -> String {
        switch error {
        case .couldNotWrite:
            return L(
                "general.advanced.backup.error.export_title",
                "Couldn't Save the Backup"
            )
        default:
            return L(
                "general.advanced.backup.error.restore_title",
                "Couldn't Restore"
            )
        }
    }
}
