import Foundation
import KiwiDeskCore

/// Global settings persistence for `gui.json` (#516).
extension SettingsModel {
    /// Copies the `gui.json`-owned global fields — the ONE field
    /// list, and both consumers ("did a global change?" and
    /// "adopt as clean") go through it: two hand-kept copies drift
    /// silently into a save that never clears the footer, or a
    /// footer that never offers the save.
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

    /// Writes `gui.json` and nothing else (#516) — no global
    /// field has a monitor dependency, so the #335 gate that
    /// rightly blocks profile saves while AX is off must not
    /// reach them. Its own narrow method on purpose: routing
    /// through `persist(named:)` drags in warnings naming a
    /// profile this save never touched.
    func saveGlobalsWhilePaused() {
        // Self-guarding on the CANONICAL predicate: a write that
        // can seize config ownership must not depend on its only
        // caller remembering to check (§5 — refine the one
        // `isGuiManaged` predicate, never mirror it).
        guard core.isGuiManaged else { return }
        // The spaces freshness net runs here too — but only when
        // live is trustworthy: on an AX-off cold boot it would
        // append StateCoordinator's boot default and the saved
        // list silently grows a spurious "1" on every save
        // (caught by a probe: the save wrote ["work","mail","1"]).
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
                // Cold paused boot: core.start() never ran, so a
                // reload here would be the session's FIRST — it
                // would execute init.lua, register hotkeys and
                // retile while the dashboard says "paused". Write
                // the store directly; start() picks the file up
                // when permission arrives.
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
        // The recorder's rollback point was minted against the
        // pre-save modes; every other save path retires it, and a
        // stale one silently reverts a staged action edit on the
        // next recorder change.
        liveKeySession = nil
    }
}
