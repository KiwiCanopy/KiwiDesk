import Foundation

/// `init.lua` in a backup (#2517): carried only when an export
/// asks, and replaced only when a restore asks and the backup
/// carries one. Off by default on both ends: a backup can come
/// from someone else, and restoring it must not run their code
/// unasked.
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
    /// anything: settings over a Lua-owned config, judged on the
    /// `init.lua` the restore leaves. One that replaces it with
    /// the backup's lands the source's setup whole, so it is not
    /// refused, and its settings apply only where the incoming
    /// file leaves them the GUI's.
    public func restoreRefusal(
        of bundle: SetupBundle,
        replacingInitLua: Bool
    ) -> SetupBundleError? {
        let incoming = replacingInitLua ? bundle.initLua : nil
        guard bundle.config != nil, incoming == nil, !isGuiManaged
        else { return nil }
        return .luaOwnsThisMac
    }

    /// The ways a restore of `bundle` may go on this Mac, one
    /// reading for Settings' buttons and the CLI's refusal alike.
    public func restoreChoices(for bundle: SetupBundle) -> RestoreChoices {
        RestoreChoices(
            plain: restoreRefusal(of: bundle, replacingInitLua: false)
                == nil,
            withInitLua: bundle.initLua != nil
        )
    }

    /// Whether the setup a restore leaves is the GUI's, where it
    /// writes `incoming` as `init.lua`; nil where it writes none.
    func restoredGuiManaged(_ incoming: String?) -> Bool? {
        incoming.map { !ManagedConfig.hasForeignCode($0) }
    }

    /// What a restore did with `init.lua`.
    static func initLuaRestore(
        of bundle: SetupBundle,
        replaced: Bool
    ) -> InitLuaRestore {
        if replaced { return .replaced }
        return bundle.initLua == nil ? .notCarried : .leftAlone
    }

    /// Writes the backup's `init.lua` over the one the restore has
    /// already moved to the Trash.
    func writeRestoredInitLua(
        _ source: String
    ) throws(SetupBundleError) {
        do {
            try source.write(
                to: configURL,
                atomically: true,
                encoding: .utf8
            )
        } catch {
            onLog("restore: init.lua write failed: \(error)")
            throw .couldNotWrite(name: configURL.lastPathComponent)
        }
    }
}

/// The ways a restore of one backup may go on this Mac (#2517).
public struct RestoreChoices: Equatable, Sendable {
    /// Restore, leaving this Mac's `init.lua` as it is.
    public let plain: Bool
    /// Restore, taking the backup's `init.lua` too.
    public let withInitLua: Bool

    /// Whether any restore is possible at all.
    public var any: Bool { plain || withInitLua }
}
