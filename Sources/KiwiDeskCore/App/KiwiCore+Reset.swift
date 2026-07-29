import Foundation

/// The two reset escape hatches (#634): forget the saved window
/// arrangement (tier 1) and Reset All Settings (tier 2).
extension KiwiCore {
    /// Tier 1: forget every saved window arrangement — both
    /// snapshot files, a wake snapshot held for replay, and the
    /// in-memory remembered window→space map — without touching
    /// any setting. The files regenerate from live state (the
    /// crash marker on the next autosave, the session file at
    /// the next clean quit), which is the point: current state,
    /// never a stale capture.
    public func discardSavedArrangement() {
        crash.discardSavedSnapshots()
        sleepWake.dropHeldSnapshot()
        state.forgetRememberedSpaces()
        onLog("saved window arrangement discarded")
    }

    /// Tier 2: back to a first-launch state for app-generated
    /// config. Trashes `gui.json` and the profiles folder (Move
    /// to Trash, so recovery stays one drag away), discards the
    /// arrangement snapshots, factory-resets the live overlay,
    /// and reloads — `loadConfig` then re-seeds the starter
    /// defaults exactly as on first launch. Deliberately
    /// untouched: `init.lua` (user-authored code — for a
    /// Lua-owned config the reload leaves its settings
    /// authoritative, as everywhere else), `palettes.json`
    /// (user-curated content), and every UserDefaults
    /// preference (language, onboarding, icon recents).
    ///
    /// The live prune BEFORE the reload matters: the first-run
    /// seed captures *live* state (`guiConfigSeed`), so
    /// deleting the files alone would write the old space list
    /// and old settings straight back into the fresh sidecar.
    ///
    /// `trash` is injectable so tests hard-delete instead of
    /// filling the real Trash; production uses the Finder
    /// Move-to-Trash call. A failed trash falls back to a hard
    /// delete — a surviving `gui.json` would flip the reload
    /// back onto the old sidecar and turn the confirmed wipe
    /// into a silent no-op, which is strictly worse than
    /// skipping the Trash courtesy. Returns whether every
    /// doomed file is actually gone; `false` (both attempts
    /// failed on the user's own config dir — effectively
    /// unreachable) leaves the log line as the trail.
    @discardableResult
    public func resetAllSettings(
        trash: (URL) throws -> Void = { url in
            try FileManager.default.trashItem(
                at: url,
                resultingItemURL: nil
            )
        }
    ) -> Bool {
        let files = FileManager.default
        var cleared = true
        for url in [guiConfigStore.url, profiles.directory]
        where files.fileExists(atPath: url.path) {
            do {
                try trash(url)
            } catch {
                onLog(
                    "reset: could not trash "
                        + "\(url.lastPathComponent) (\(error)); "
                        + "deleting instead"
                )
                do {
                    try files.removeItem(at: url)
                } catch {
                    onLog(
                        "reset: could not delete "
                            + "\(url.lastPathComponent): "
                            + "\(error)"
                    )
                    cleared = false
                }
            }
        }
        discardSavedArrangement()
        profiles.resetAdoption()
        spacePins = [:]
        mainSpaces = []
        tiler.settings = TilingSettings()
        // Live spaces down to the first-launch set before the
        // reload's seed reads them; windows are forwarded, so
        // nothing is stranded in a pruned space. The target
        // depends on who owns settings: a GUI-managed config's
        // first launch seeds the starter ladder, but a
        // Lua-owned one (`configDeclaresManagedSettings`) never
        // gets a ladder — its first launch is the single
        // default space plus whatever the Lua declares on the
        // reload below, so grafting starter spaces here would
        // produce a state no first launch ever shows.
        let fresh =
            configDeclaresManagedSettings
            ? [SpaceID(1)]
            : starterSpaces()
        for space in fresh {
            state.workspaces.ensureSpace(space)
        }
        state.workspaces.reorder(matching: fresh)
        pruneSpaces(keeping: Set(fresh), orderedBy: fresh)
        // The first-launch path proper: seeds gui.json, the
        // starter shortcuts, and the Starter profile (no
        // sidecar, no profiles left).
        loadConfig()
        resolveSpaceDisplays()
        retile(force: true)
        emitSpaceChange()
        onLog("all settings reset to defaults")
        return cleared
    }
}
