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
    /// `loadConfig` runs before the event loop's first
    /// `publishDisplays`, so displays aren't in state yet — the
    /// ladder needs them for its pins and for a non-empty monitor
    /// set (without which the first `handleMonitorChange` couldn't
    /// match the profile and would drop it for a composed
    /// Standard). So it reads the same `NSScreen` source and
    /// populates state first, then applies through the one
    /// canonical path — `applyStandard` — which composes, sets
    /// modes/pins/tuning, adopts, and saves (setting `currentName`,
    /// so every later reload re-applies it via
    /// `reapplyActiveProfileState`). First-run-only: the caller
    /// gates it on the same signal as the `gui.json` seed plus an
    /// empty profile list, so an existing setup is never touched.
    func seedFirstRunStarterProfile() {
        let displays = firstRunDisplays()
        guard !displays.isEmpty else {
            onLog(
                "first run: no displays detected; skipped the "
                    + "Starter profile seed"
            )
            return
        }
        // Populate state so pins resolve and `buildProfile`
        // captures a real monitor set. The event loop re-publishes
        // the same set later — an idempotent state re-apply, whose
        // `handleMonitorChange` is then the step that matches and
        // keeps this profile.
        state.apply(.displaysChanged(displays))
        do {
            try applyStandard(
                StarterLadder.standardLayout(
                    displayCount: displays.count
                )
            )
        } catch {
            onLog(
                "first run: could not seed the Starter profile: "
                    + "\(error)"
            )
        }
    }
}
