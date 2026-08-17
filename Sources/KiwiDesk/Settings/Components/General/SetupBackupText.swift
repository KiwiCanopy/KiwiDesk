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
        case .unreadableSettings:
            return L(
                "general.advanced.backup.error.unreadable_settings",
                "KiwiDesk can't read this Mac's settings file, so "
                    + "a backup would leave your settings out. Fix "
                    + "or reset the configuration first."
            )
        case .luaOwnsThisMac:
            return L(
                "general.advanced.backup.error.lua_owned",
                "This Mac's settings come from your init.lua, so "
                    + "a backup's settings can't be applied here. "
                    + "Switch to the visual editor first, or "
                    + "restore onto a Mac that uses it."
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

    /// What a restore could not take, in one sentence.
    ///
    /// Counts sit **last behind a label** so no locale has to
    /// agree with a number mid-sentence (`localization.md`), which
    /// is also why this is two sentences rather than one frame
    /// carrying both numbers.
    static func sentence(for outcome: RestoreOutcome) -> String {
        var parts: [String] = []
        if !outcome.skippedProfiles.isEmpty {
            parts.append(
                L(
                    "general.advanced.backup.restore.skipped"
                        + ".profiles",
                    "Profiles that couldn't be read: %1$d",
                    outcome.skippedProfiles.count
                )
            )
        }
        if outcome.refusedPalettes > 0 {
            parts.append(
                L(
                    "general.advanced.backup.restore.skipped"
                        + ".palettes",
                    "Color palettes skipped: %1$d",
                    outcome.refusedPalettes
                )
            )
        }
        return parts.joined(separator: "\n")
    }

    /// The partial-restore alert's title. Not an error title: the
    /// restore happened, and saying otherwise would send a user
    /// looking for a failure that is not there.
    static var partialTitle: String {
        L(
            "general.advanced.backup.restore.partial_title",
            "Restored, with Some Items Skipped"
        )
    }

    /// The alert's title — one for every case, because a title
    /// that changes per cause reads as five different failures of
    /// five different features.
    static func title(for error: SetupBundleError) -> String {
        switch error {
        case .couldNotWrite, .unreadableSettings:
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
