import KiwiDeskCore

/// Localized error and status message rendering for backup bundle operations
/// (#96).
@MainActor
enum SetupBackupText {
    /// Formats localized error sentence for SetupBundleError.
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
            // interpolated: they name an internal format, not an
            // app version a user could act on — the sentence that
            // helps is the one saying what to do.
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
        case .unreadablePalettes:
            return L(
                "general.advanced.backup.error.unreadable_palettes",
                "KiwiDesk can't read this Mac's saved color "
                    + "palettes, so a backup would leave them "
                    + "out. They may come from a newer KiwiDesk."
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

    /// Formats skipped item counts for a partial restore. Counts
    /// sit LAST behind a label so no locale has to agree with a
    /// number mid-sentence (`localization.md`) — which is why this
    /// is two sentences rather than one frame carrying both
    /// numbers.
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

    /// Title for partial restore alert.
    static var partialTitle: String {
        L(
            "general.advanced.backup.restore.partial_title",
            "Restored, with Some Items Skipped"
        )
    }

    /// Alert title — one for every case, because a title that
    /// changes per cause reads as five different failures of five
    /// different features.
    static func title(for error: SetupBundleError) -> String {
        switch error {
        case .couldNotWrite, .unreadableSettings,
            .unreadablePalettes:
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
