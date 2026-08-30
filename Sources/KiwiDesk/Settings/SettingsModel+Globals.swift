import Foundation
import KiwiDeskCore

/// Global settings persistence for `gui.json` (#516).
extension SettingsModel {
    /// Copies all `gui.json`-owned global fields from `source` into `target`.
    static func copyGlobals(
        from source: GuiConfig,
        into target: inout GuiConfig
    ) {
        target.format = source.format
        target.layers = source.layers
        target.appRules = source.appRules
        target.floatRules = source.floatRules
        target.ignoreRules = source.ignoreRules
        target.profileBindings = source.profileBindings
        target.spaces = source.spaces
    }

    var globalsChanged: Bool {
        guard let saved = savedSidecar else { return true }
        var probe = saved
        Self.copyGlobals(from: config, into: &probe)
        return probe != saved
    }

    /// Persists `gui.json` globals when AX is off (#516, #335).
    func saveGlobalsWhilePaused() {
        guard core.isGuiManaged else { return }
        if core.state.workspaces.allSpaces.map(\.id)
            != [SpaceID(1)]
        {
            core.mergeLiveSpaces(
                into: &config,
                seededWith: seedSpaces
            )
            seedSpaces = config.spaces
        }
        do {
            if core.lua == nil {
                try core.guiConfigStore.save(config)
            } else {
                try core.saveGuiConfig(config)
            }
        } catch {
            profileWarning = L(
                "settings.globals_save_failed",
                "Saving settings failed: %1$@",
                "\(error)"
            )
            core.onLog("globals save failed: \(error)")
            return
        }
        adoptGlobalsBaseline()
    }

    /// Marks global fields clean without wiping unpersisted tiling edits.
    private func adoptGlobalsBaseline() {
        Self.copyGlobals(from: config, into: &cleanConfig)
        var sidecar = savedSidecar ?? config
        Self.copyGlobals(from: config, into: &sidecar)
        savedSidecar = sidecar
        recomputeDirty()
        refreshProfiles()
        liveKeySession = nil
    }
}
