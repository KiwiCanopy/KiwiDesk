import Foundation

extension KiwiCore {
    /// Renames a saved profile and chases every reference the
    /// core owns: the file + adopted name (`ProfileManager`),
    /// the runtime native-Space bindings, and — when a
    /// `gui.json` sidecar exists — the sidecar's binding
    /// lines, which would otherwise go stale: `loadGuiConfig`
    /// composes bindings from the RUNTIME map only on the
    /// no-sidecar seed path. The follow-up save lives here,
    /// not in the GUI, so every rename entry point (CLI/Lua
    /// later) inherits it. No sidecar is ever CREATED here —
    /// that would flip a hand-written config to GUI-managed.
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
        guard chased, guiConfigStore.exists else { return }
        var live = loadGuiConfig()
        live.profileBindings = nativeSpaceBindings
        try saveGuiConfig(live)
    }
}
