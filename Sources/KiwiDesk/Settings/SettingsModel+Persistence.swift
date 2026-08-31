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
            liveKeySession = nil
            core.loadConfig()
            reload()
            warnIfAnyConflict()
        } catch {
            core.onLog("settings save failed: \(error)")
        }
    }

    /// Reverts staged edits and reapplies profile if layout drifted (#123).
    func revert() {
        if computeLayoutDrift() != nil,
            let activeProfileName = activeProfile
        {
            core.reapplyIfInEffect(activeProfileName)
        }
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
