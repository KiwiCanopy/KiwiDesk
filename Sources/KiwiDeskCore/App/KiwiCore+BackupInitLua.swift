import Foundation

/// `init.lua` in a backup (#2517): carried only when an export
/// asks, and replaced only when a restore asks and the backup
/// carries one. Off by default on both ends: a backup can come
/// from someone else, and restoring it must not run their code
/// unasked. A sync take (#2324) replaces it through the same
/// writer.
extension KiwiCore {
    /// This install's `init.lua` for an export that asked, nil
    /// where there is none.
    func initLuaForBackup() throws(SetupBundleError) -> String? {
        guard FileManager.default.fileExists(atPath: configURL.path)
        else { return nil }
        guard
            let source = try? String(
                contentsOf: configURL,
                encoding: .utf8
            )
        else { throw .unreadableInitLua }
        return source
    }

    /// The refusal a restore of `bundle` meets before it touches
    /// anything: nothing to write for the restore chosen, or
    /// settings over a Lua-owned config — judged on the `init.lua`
    /// the restore leaves. One that replaces it lands the source's
    /// setup whole, so it is not refused over ownership, and its
    /// settings apply only where the incoming file leaves them the
    /// GUI's (`IncomingInitLua.leavesSettingsToGui`).
    public func restoreRefusal(
        of bundle: SetupBundle,
        replacingInitLua: Bool
    ) -> SetupBundleError? {
        let incoming = replacingInitLua ? bundle.initLua : nil
        guard incoming == nil else { return nil }
        if !bundle.carriesSetup { return .empty }
        guard bundle.config != nil, !isGuiManaged else { return nil }
        return .luaOwnsThisMac
    }

    /// The ways a restore of `bundle` may go on this Mac, one
    /// reading for Settings' buttons and the CLI's refusal alike.
    public func restoreChoices(for bundle: SetupBundle) -> RestoreChoices {
        RestoreChoices(
            plainRefusal: restoreRefusal(
                of: bundle,
                replacingInitLua: false
            ),
            withInitLua: bundle.initLua != nil
                && restoreRefusal(of: bundle, replacingInitLua: true)
                    == nil
        )
    }

    /// What a restore did with `init.lua`.
    static func initLuaRestore(
        of bundle: SetupBundle,
        replaced: Bool
    ) -> InitLuaRestore {
        if replaced { return .replaced }
        return bundle.initLua == nil ? .notCarried : .leftAlone
    }

    /// Writes the incoming `init.lua` over the one the replace has
    /// already moved to the Trash. False where it failed; nothing
    /// to write is no failure.
    func writeIncomingInitLua(_ incoming: IncomingInitLua) -> Bool {
        guard case .replace(let source?) = incoming else { return true }
        do {
            try source.write(to: configURL, options: .atomic)
            return true
        } catch {
            onLog("restore: init.lua write failed: \(error)")
            return false
        }
    }
}

/// What a replace of this Mac's setup does with `init.lua`.
enum IncomingInitLua {
    /// This Mac's stays.
    case keep
    /// This Mac's goes to the Trash and `source` takes its place;
    /// nil leaves none, as a sync folder without one does.
    case replace(Data?)

    var replaces: Bool {
        if case .replace = self { return true }
        return false
    }

    /// Whether the setup the replace leaves is the GUI's, judged on
    /// the incoming file: one with foreign code owns the settings
    /// itself, so the incoming `gui.json` is not applied.
    var leavesSettingsToGui: Bool {
        guard case .replace(let source?) = self else { return true }
        return !ManagedConfig.hasForeignCode(
            String(decoding: source, as: UTF8.self)
        )
    }
}

/// The ways a restore of one backup may go on this Mac (#2517).
public struct RestoreChoices: Equatable, Sendable {
    /// Why a restore leaving this Mac's `init.lua` is refused, nil
    /// where it is offered — `.empty` for a backup carrying only
    /// `init.lua`, `.luaOwnsThisMac` for settings over one.
    public let plainRefusal: SetupBundleError?
    /// Restore, leaving this Mac's `init.lua` as it is.
    public var plain: Bool { plainRefusal == nil }
    /// Restore, taking the backup's `init.lua` too.
    public let withInitLua: Bool

    /// Whether any restore is possible at all.
    public var any: Bool { plain || withInitLua }
}
