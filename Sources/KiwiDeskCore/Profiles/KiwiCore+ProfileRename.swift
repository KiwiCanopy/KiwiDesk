import Foundation

extension KiwiCore {
    /// Renames a saved profile and chases every reference the
    /// core owns: the file + adopted name (`ProfileManager`),
    /// the runtime native-Space bindings, and — when a
    /// readable `gui.json` sidecar exists — the sidecar's
    /// binding lines, which would otherwise go stale:
    /// `loadGuiConfig` composes bindings from the RUNTIME map
    /// only on the no-sidecar seed path. The follow-up save
    /// lives here, not in the GUI, so every rename entry
    /// point (CLI/Lua later) inherits it. Bounds:
    /// - Never creates a sidecar (that would flip a
    ///   hand-written config to GUI-managed) and never
    ///   overwrites one that no longer decodes (an unreadable
    ///   sidecar surfaces as a config issue instead).
    /// - A follow-up save failure is logged, not thrown: the
    ///   rename is already complete and the runtime map
    ///   chased — the sidecar merely lags one save. A throw
    ///   from here always means the rename itself failed.
    /// - In a hybrid config (sidecar + foreign Lua) the
    ///   reload re-registers init.lua's own binding lines,
    ///   which stay the user's to update — init.lua is never
    ///   touched.
    /// - The save triggers `loadConfig()`, which tears down
    ///   the Lua VM synchronously; a future Lua-exposed
    ///   rename verb must defer it the way `reload_config`
    ///   does.
    public func renameProfile(
        from old: String,
        to new: String
    ) throws {
        try profiles.rename(from: old, to: new)
        var chased = false
        for (number, name) in nativeSpaceBindings
        where name == old {
            nativeSpaceBindings[number] = new
            chased = true
        }
        guard chased, guiConfigStore.load() != nil else {
            return
        }
        var live = loadGuiConfig()
        live.profileBindings = nativeSpaceBindings
        do {
            try saveGuiConfig(live)
        } catch {
            onLog("rename: sidecar follow failed: \(error)")
        }
    }
}
