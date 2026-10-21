import Foundation

/// `export_setup` and `restore_setup` (#2517): the Settings
/// backup's Export… and Restore…, from the command line. CLI only
/// (`cliOnly`) — an `init.lua` restoring a backup on every load is
/// a loop — and `restore_setup` is destructive, so `kiwidesk mcp`
/// reaches it only through `run_destructive`. Replies and
/// refusals are English, a CLI contract (core-boundaries.md).
extension KiwiCore {
    nonisolated public static let exportSetupCommand = "export_setup"
    nonisolated public static let restoreSetupCommand = "restore_setup"
    /// `export_setup`'s opt-in: carry `init.lua` in the backup.
    nonisolated public static let includeInitLuaFlag = "--include-init-lua"
    /// `restore_setup`'s opt-in: take the backup's `init.lua`.
    nonisolated public static let initLuaFlag = "--init-lua"

    func runExportSetup(_ args: [JSONValue]) -> CommandResponse {
        let parsed = Self.backupArguments(
            args,
            flag: Self.includeInitLuaFlag
        )
        guard case .success(let (url, include)) = parsed else {
            return parsed.refusal
        }
        do {
            try writeBackup(to: url, includingInitLua: include)
        } catch {
            return .fail(error.cliMessage)
        }
        let carried =
            include
            ? (configURLExists ? "included" : "none") : "not_asked"
        return .ok(
            .object([
                "path": .string(url.path),
                "init_lua": .string(carried),
            ])
        )
    }

    func runRestoreSetup(_ args: [JSONValue]) -> CommandResponse {
        let parsed = Self.backupArguments(args, flag: Self.initLuaFlag)
        guard case .success(let (url, replacing)) = parsed else {
            return parsed.refusal
        }
        do {
            let bundle = try readBackup(at: url)
            // The Trash Core writes to when no GUI hands one,
            // pinned to a delete in every test core.
            let outcome = try restoreSetup(
                from: bundle,
                replacingInitLua: replacing,
                trash: sync.trash
            )
            onSetupRestored()
            return .ok(
                .object([
                    "init_lua": .string(outcome.initLua.rawValue),
                    "skipped_profiles": .array(
                        outcome.skippedProfiles.map { .string($0) }
                    ),
                    "refused_palettes": .number(
                        Double(outcome.refusedPalettes)
                    ),
                    "refused_looks": .number(
                        Double(outcome.refusedLooks)
                    ),
                ])
            )
        } catch {
            // Only a write failure has touched the files; a refusal
            // leaves an open Settings draft as it is.
            if case .couldNotWrite = error { onSetupRestored() }
            return .fail(error.cliMessage)
        }
    }

    private var configURLExists: Bool {
        FileManager.default.fileExists(atPath: configURL.path)
    }

    /// The path and the opt-in flag, in either order. A relative
    /// path is refused: the app's working directory is not the
    /// caller's, and the CLI resolves one before it sends.
    static func backupArguments(
        _ args: [JSONValue],
        flag: String
    ) -> BackupArguments {
        var path: String?
        var flagged = false
        for arg in args {
            guard let text = arg.stringValue else {
                return .failure("expected a file path")
            }
            if text == flag {
                flagged = true
            } else if path == nil {
                path = text
            } else {
                return .failure("unexpected argument: \(text)")
            }
        }
        guard let path, !path.isEmpty else {
            return .failure("expected a file path")
        }
        guard path.hasPrefix("/") else {
            return .failure("expected an absolute path: \(path)")
        }
        return .success((URL(fileURLWithPath: path), flagged))
    }
}

/// `backupArguments`' answer: the file and the flag, or a refusal.
enum BackupArguments {
    case success((URL, Bool))
    case failure(String)

    var refusal: CommandResponse {
        if case .failure(let message) = self { return .fail(message) }
        return .fail("expected a file path")
    }
}

extension SetupBundleError {
    /// The English a CLI reply carries (core-boundaries.md).
    var cliMessage: String {
        switch self {
        case .unreadable: return "the file could not be read"
        case .notABackup: return "the file is not a KiwiDesk backup"
        case .newerFormat(let found, let supported):
            return "the backup is format \(found); this KiwiDesk "
                + "reads up to \(supported)"
        case .empty: return "the backup has nothing to restore"
        case .couldNotWrite(let name): return "could not write \(name)"
        case .unreadableSettings: return "gui.json could not be read"
        case .unreadablePalettes:
            return "palettes.json could not be read"
        case .unreadableLooks: return "looks.json could not be read"
        case .unreadableInitLua: return "init.lua could not be read"
        case .luaOwnsThisMac:
            return "init.lua owns this Mac's setup, so the backup's "
                + "settings would not apply; restore with "
                + KiwiCore.initLuaFlag + " if the backup carries one"
        }
    }
}
