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
        case .unreadableLooks:
            return L(
                "general.advanced.backup.error.unreadable_looks",
                "KiwiDesk can't read this Mac's saved looks, so a "
                    + "backup would leave them out. They may come "
                    + "from a newer KiwiDesk."
            )
        case .unreadableInitLua:
            return L(
                "general.advanced.backup.error.unreadable_init_lua",
                "KiwiDesk can't read this Mac's init.lua, so a "
                    + "backup including it can't be made."
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
                "common.error.write_failed",
                "KiwiDesk couldn't write “%1$@”. Try somewhere "
                    + "else, like your Desktop.",
                name
            )
        }
    }

    /// Formats skipped item counts summary for partial restore outcome.
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
        if outcome.refusedLooks > 0 {
            parts.append(
                L(
                    "general.advanced.backup.restore.skipped"
                        + ".looks",
                    "Looks skipped: %1$d",
                    outcome.refusedLooks
                )
            )
        }
        return parts.joined(separator: "\n")
    }

    /// The confirm's plain Restore, leaving this Mac's init.lua.
    static var restoreLabel: String {
        L("general.advanced.backup.restore.confirm", "Restore")
    }

    /// The confirm's Restore that takes the backup's init.lua too
    /// (#2517).
    static var restoreWithInitLuaLabel: String {
        L(
            "general.advanced.backup.restore.confirm.with_init_lua",
            "Restore with init.lua"
        )
    }

    /// The confirm's message: what every restore replaces, then
    /// what each offered button does with init.lua (#2517).
    static func restoreMessage(_ choices: RestoreChoices) -> String {
        let lead = L(
            "general.advanced.backup.restore.confirm.lead",
            "This replaces your settings, every profile, and your "
                + "color palettes and looks with what's in the "
                + "backup file — and discards any changes you "
                + "haven't saved yet. The files being replaced go "
                + "to the Trash."
        )
        let tail: String
        if !choices.withInitLua {
            tail = L(
                "general.advanced.backup.restore.confirm.no_init_lua",
                "init.lua isn't touched."
            )
        } else if choices.plain {
            tail = L(
                "general.advanced.backup.restore.confirm.choose_init_lua",
                "The backup also includes an init.lua. “%1$@” leaves "
                    + "yours as it is; “%2$@” puts the backup's in "
                    + "its place and KiwiDesk runs it.",
                restoreLabel,
                restoreWithInitLuaLabel
            )
        } else {
            tail = L(
                "general.advanced.backup.restore.confirm.lua_owned",
                "Your settings here come from init.lua, so this "
                    + "backup can only be restored together with its "
                    + "own init.lua, which KiwiDesk then runs."
            )
        }
        return lead + " " + tail
    }

    /// Title for partial restore alert.
    static var partialTitle: String {
        L(
            "general.advanced.backup.restore.partial_title",
            "Restored, with Some Items Skipped"
        )
    }

    /// Alert title for backup or restore failure.
    static func title(for error: SetupBundleError) -> String {
        switch error {
        case .couldNotWrite, .unreadableSettings,
            .unreadablePalettes, .unreadableLooks, .unreadableInitLua:
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
