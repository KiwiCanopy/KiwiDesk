import KiwiDeskCore

/// Writing the edited config back out: the raw Lua editor's save,
/// the staged-edit revert, and adopting a hand-written file into
/// GUI management. Split out of `SettingsModel` for the 350-line
/// ceiling — the published state stays in the main file, because
/// `@Published` cannot live in an extension.
extension SettingsModel {
    /// Writes the raw Lua editor's buffer to disk and reloads.
    func saveLuaSource() {
        do {
            try luaSource.write(
                to: configURL,
                atomically: true,
                encoding: .utf8
            )
            // The raw file is now authoritative. Its reload
            // replaces every hotkey, so the recorder snapshot
            // must not roll the freshly loaded Lua table back.
            liveKeySession = nil
            core.loadConfig()
            reload()
            // Free-form Lua isn't checked at input time (no
            // recorder was involved), so set or clear the
            // banner here from the reloaded config.
            warnIfAnyConflict()
        } catch {
            core.onLog("settings save failed: \(error)")
        }
    }

    func revert() {
        // Re-applying the profile (restores the saved layout,
        // prunes stale spaces, force-retiles) is gated on
        // actual drift — a plain staged-edit revert stays
        // model-only, as before #123. Computed fresh, not from
        // the published snapshot, so a switch the UI hasn't
        // caught up with still reverts.
        if computeLayoutDrift() != nil,
            let activeProfileName = activeProfile
        {
            core.reapplyIfInEffect(activeProfileName)
        }
        reload()
    }

    /// Migrates a hand-written config into GUI management (the
    /// old file is kept as a commented backup) and switches to
    /// the visual editor. See `KiwiCore.adoptConfigIntoGui`.
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
