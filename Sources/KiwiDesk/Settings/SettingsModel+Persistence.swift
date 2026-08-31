import KiwiDeskCore

/// Configuration persistence, revert, and GUI adoption actions
/// for SettingsModel.
extension SettingsModel {
    /// Writes raw Lua editor buffer to disk and reloads runtime state.
    func saveLuaSource() {
        do {
            try luaSource.write(
                to: configURL,
                atomically: true,
                encoding: .utf8
            )
            // The reload replaces every hotkey; the recorder
            // snapshot must not roll the fresh Lua table back.
            liveKeySession = nil
            core.loadConfig()
            reload()
            // Free-form Lua isn't checked at input time, so set or
            // clear the conflict banner from the reloaded config.
            warnIfAnyConflict()
        } catch {
            core.onLog("settings save failed: \(error)")
        }
    }

    /// Discards the staged draft. Model-only, as before #123
    /// and again since #1179: a quick-menu layout switch is the
    /// session's, not the draft's, so Revert has nothing to say
    /// about it — ending a temporary layout is the quick menu's
    /// job (switch back, or Keep).
    func revert() {
        reload()
    }

    /// Adopts hand-written config into GUI management
    /// (`KiwiCore.adoptConfigIntoGui`).
    func adoptIntoGui() {
        do {
            try core.adoptConfigIntoGui()
            showLuaEditor = false
            reload()
            // Adopt recovers the file's keybindings (see
            // adoptConfigIntoGui / recoverKeybindings), so a
            // conflict can arrive with the seeded config: set or
            // clear the banner from the result, matching the
            // Lua-editor save path.
            warnIfAnyConflict()
        } catch {
            core.onLog("adopt failed: \(error)")
        }
    }
}
