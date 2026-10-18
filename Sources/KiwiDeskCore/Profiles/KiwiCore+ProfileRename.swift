import Foundation

extension KiwiCore {
    /// Renames a saved profile and chases every reference the
    /// core owns: the file + adopted name (`ProfileManager`),
    /// the runtime native-Space bindings, and — when a
    /// readable `gui.json` sidecar exists — the sidecar's
    /// binding lines through `rewriteSidecarBindings`, which
    /// would otherwise go stale. The follow-up save
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
        defer { promotePendingBindings() }
        // #1230: the partitioning is keyed by profile NAME, so it
        // follows the rename or the profile loses its own Spaces.
        state.profilePartitioning.rename(old, to: new)
        renameAppWideCapture(old, to: new)
        // A binding names the id (#2324), so only its LABEL
        // follows; a pending entry follows by name as before.
        let id = (try? profiles.read(name: new))?.id
        func names(_ binding: DesktopBinding) -> Bool {
            binding.entries.contains {
                (id != nil && $0.id == id)
                    || ($0.id == nil && $0.name == old)
            }
        }
        var chased = false
        for (key, binding) in desktopBindings where names(binding) {
            desktopBindings[key]?.relabel(id, from: old, to: new)
            chased = true
        }
        guard chased else { return }
        // Matching VALUES in the sidecar's own map — never the
        // runtime map, which in a hybrid config also holds
        // init.lua's bindings (deleting the Lua line would then
        // resurrect the binding).
        do {
            try rewriteSidecarBindings { bindings in
                for (key, binding) in bindings where names(binding) {
                    bindings[key]?.relabel(id, from: old, to: new)
                }
            }
        } catch SidecarError.missing {
            // A hand-written config: nothing to follow.
        } catch {
            onLog("rename: sidecar follow failed: \(error)")
        }
    }
}
