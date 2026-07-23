import Foundation

/// First-run materialization of the beginner ladder (#466).
extension KiwiCore {
    /// Materializes the beginner ladder as a real, adopted
    /// "Starter" profile on a fresh first run — the only durable
    /// home for the per-space modes, monitor pins, and tuning that
    /// `gui.json` (globals only) can't carry. The `gui.json` seed
    /// already wrote the matching space list and scaled shortcuts;
    /// this lays the profile-scoped half on top and persists it.
    ///
    /// Runs from `loadConfig` after `reconcileAll` has populated
    /// displays, so `allDisplays` is authoritative — and before
    /// the event loop's first `handleMonitorChange`, which then
    /// finds this profile as an exact match and keeps it. Saving
    /// adopts it (`currentName`), so every later reload re-applies
    /// it via `reapplyActiveProfileState`. First-run-only: the
    /// caller gates it on the same signal as the `gui.json` seed,
    /// so a monitor added later never re-seeds.
    func seedFirstRunStarterProfile() {
        let ordered = PositionalDisplays.ordered(
            state.workspaces.allDisplays,
            mainID: PositionalDisplays.liveMainID
        )
        let count = max(1, ordered.count)
        let spaces = StarterLadder.spaces(displayCount: count)
        for space in spaces {
            state.workspaces.ensureSpace(space)
        }
        state.workspaces.reorder(matching: spaces)

        // Per-space modes (sparse map ⇒ bsp fallback).
        let modes = StarterLadder.spaceModes(displayCount: count)
        for space in spaces {
            setSpaceMode(space, modes[space] ?? .bsp)
        }

        // Pin each display's block to its ordered fingerprint; the
        // main block takes the Main role. A block whose display
        // isn't connected (can't happen at seed time, defensive)
        // falls back to Main.
        var pins: [SpaceID: String] = [:]
        var mains: Set<SpaceID> = []
        for space in spaces {
            let screen = StarterLadder.screen(of: space)
            if screen >= 1, screen < ordered.count {
                pins[space] = ordered[screen].fingerprint
            } else {
                mains.insert(space)
            }
        }
        spacePins = pins
        mainSpaces = mains

        // Wholesale, so the seeded profile's settings match exactly
        // what applying the Starter preset would produce (on a
        // fresh run the live settings are still the defaults).
        tiler.settings = StarterLadder.settings()

        resolveSpaceDisplays()

        // Durable + adopted: `save` writes the JSON and sets
        // `currentName`, so `reapplyActiveProfileState` reloads it.
        do {
            try profiles.save(
                buildProfile(name: profiles.freeName(base: "Starter"))
            )
        } catch {
            onLog(
                "first run: could not save the Starter profile: "
                    + "\(error)"
            )
        }
        retile(force: true)
        emitSpaceChange()
    }
}
