import Foundation

/// Profile selection on monitor reconfiguration (#36), split out
/// of `KiwiCore+ProfileResolution` for file size. Decides which
/// profile (or composed Standard) to apply when displays change.
extension KiwiCore {
    /// Profile selection on monitor reconfiguration (#36):
    /// exact stored set → adopt clean; the count's default
    /// user profile → load dirty; else compose the built-in
    /// Standard (#53) → transient dirty state.
    func handleMonitorChange() {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return }
        // No exit may leave a space orphaned (#676): the state
        // fold already ran, and any display id churn (sleep,
        // dock/undock — #676's report was an AirPlay connect
        // re-keying the built-in) wiped every `spaceDisplay`
        // entry on the old id. A branch that skips re-resolving
        // — `.countDefault` with the profile already current
        // did — leaves both bars' display keys unresolvable, so
        // the trailing retile retires them with nothing to
        // heal. Resolve on every exit. The obligation this
        // rests on: a branch finishes mutating every resolve
        // input (`spacePins`, profile adoption) before its own
        // resolve/retile, so the deferred pass re-runs on
        // identical inputs and moves nothing —
        // `MonitorChangeSpaceResolveTests` pins that a second
        // immediate resolve is a no-op.
        defer { resolveSpaceDisplays() }
        let fingerprints = displays.map(\.fingerprint)

        // A native-Space binding wins over matching (#7); a
        // binding that fails to load falls through to matching.
        // The Desktop that counts is the main display's (#888).
        //
        // ONE stamped reading (#1147): a display that just
        // returned brings Desktops macOS created fresh, which are
        // stamped here before the binding resolves against them.
        let desktops = stampedDesktopSnapshot()
        if let key = desktops.mainCurrentKey,
            let binding = desktopBindings[key]
        {
            let boundName = binding.profile
            do {
                let bound = try profiles.load(name: boundName)
                apply(profile: bound, forceRetile: false)
                if bound.set(matching: fingerprints) == nil {
                    profiles.markDirty()
                }
                onLog(
                    "monitor change: loaded bound profile "
                        + "'\(boundName)'"
                )
                return
            } catch {
                onLog(
                    "cannot load bound profile "
                        + "'\(boundName)': \(error)"
                )
            }
        }

        switch profiles.match(fingerprints: fingerprints) {
        case .exact(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile, forceRetile: false)
                profiles.adopt(profile)
                onLog(
                    "monitor change: loaded profile "
                        + "'\(profile.name)'"
                )
            } else {
                // Same profile back on one of its exact sets
                // (e.g. re-docked after an interim mismatch):
                // re-adopt so a lingering dirty flag clears;
                // the deferred resolve picks up that set's
                // pins — nothing runs between here and it.
                profiles.adopt(profile)
                spacePins =
                    profile.set(matching: fingerprints)?
                    .spaceMonitorMap ?? [:]
            }
        case .countDefault(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile, forceRetile: false)
                profiles.adopt(profile)
                onLog(
                    "monitor change: loaded default profile "
                        + "'\(profile.name)' (dirty)"
                )
            }
            profiles.markDirty()
        case .none:
            // On the starter setup baseline, recompose the
            // setup at the live display count instead of a
            // workflow Standard, so the five-per-display shape
            // survives the change (#485). Any other baseline gets
            // the count's built-in Standard, unchanged (#53).
            guard
                let composed = composeMonitorChangeFallback(
                    displays: displays
                )
            else { return }
            // A hand-written or hybrid Lua config keeps
            // owning tiling: the Standard only steers
            // placement and no transient-standard state is
            // adopted, so with no active profile the Lua base
            // survives reloads untouched (#36 promise). A
            // still-active profile keeps its tiling and its
            // still-valid pins, but goes dirty — the same
            // rule as load_profile onto other hardware.
            guard isGuiManaged else {
                if profiles.currentName != nil {
                    profiles.markDirty()
                }
                // NOT redundant with the deferred resolve:
                // this branch retiles and emits below, and two
                // callers (`delete_profile`, the reload
                // re-apply's else-arm) run no trailing retile —
                // only a resolve BEFORE this retile places
                // windows correctly there. The deferred pass
                // then re-runs on identical inputs and moves
                // nothing.
                resolveSpaceDisplays()
                retile()
                emitSpaceChange()
                onLog(
                    "monitor change: no matching profile, "
                        + "placement follows standard "
                        + "'\(composed.sourceName)' (tiling "
                        + "stays Lua/profile-owned)"
                )
                return
            }
            // `apply(composed:)` adopts the composed placement, so
            // the setup's five-per-display blocks land correctly
            // (not scattered into the workflow Standard's slots).
            apply(composed: composed, forceRetile: false)
            profiles.adoptStandard(named: composed.sourceName)
            // Bind ⌃⌥N for spaces the change added past the
            // first-run seed — additive, never overwriting a
            // custom chord (#485).
            topUpDigitShortcuts()
            onLog(
                "monitor change: no matching profile, "
                    + "composed standard '\(composed.sourceName)'"
            )
        }
    }
}
