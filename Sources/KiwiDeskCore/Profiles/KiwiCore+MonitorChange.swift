import Foundation

/// Profile selection on monitor reconfiguration (#36), split out
/// of `KiwiCore+ProfileResolution` for file size. Decides which
/// profile (or composed Standard) to apply when displays change.
extension KiwiCore {
    /// Profile selection on monitor reconfiguration (#36):
    /// exact stored set → adopt clean; the count's default
    /// user profile → load dirty; else compose the built-in
    /// Standard (#53) → transient dirty state. Answers the
    /// Standard it composed, which only the screen-change doors
    /// announce (`handleScreenChange`, #3646).
    @discardableResult
    func handleMonitorChange() -> StandardFallback? {
        let displays = state.workspaces.allDisplays
        guard !displays.isEmpty else { return nil }
        supersedeMonitorSettle()
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
        let fingerprints = liveFingerprints

        // A native-Space binding wins over matching (#7); a
        // binding that fails to load, or is for another screen
        // count (#1394), falls through to matching. The Desktop
        // that counts is the main display's (#888).
        //
        // ONE stamped reading (#1147): a display that just
        // returned brings Desktops macOS created fresh, which are
        // stamped here before the binding resolves against them.
        let desktops = stampedDesktopSnapshot()
        desktopMemory.fileShownUserSpaces(desktops)
        if let binding = mainDesktopBinding(in: desktops) {
            switch boundProfile(of: binding) {
            case .success(let pick):
                apply(profile: pick.profile, cause: .monitorChange)
                onLog(
                    "monitor change: loaded bound profile "
                        + "'\(pick.profile.name)'"
                )
                return nil
            case .failure(let refusal):
                onLog(
                    "monitor change: "
                        + refusal.narrative(binding: binding)
                )
            }
        }

        var composedFallback: StandardFallback?
        switch profiles.match(fingerprints: fingerprints) {
        case .exact(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile, cause: .monitorChange)
                onLog(
                    "monitor change: loaded profile "
                        + "'\(profile.name)'"
                )
            } else {
                // Same profile back on one of its exact sets
                // (e.g. re-docked after an interim mismatch):
                // no apply runs, so clear the lingering dirty
                // flag here — an exact match IS the #36 fit. The
                // deferred resolve picks up that set's pins;
                // nothing runs between here and it.
                profiles.markClean()
                spacePins = keepingPins(
                    of: Set(liveTemporarySpaces),
                    over: runtimePins(of: profile)
                )
                returnHeldSpacesWithoutApply(to: profile)
            }
        case .countDefault(let profile):
            if profile.name != profiles.currentName {
                apply(profile: profile, cause: .monitorChange)
                onLog(
                    "monitor change: loaded default profile "
                        + "'\(profile.name)' (dirty)"
                )
            } else {
                // The same profile on a same-count setup it does not
                // hold: its numbers land left to right (#3647).
                spacePins = keepingPins(
                    of: Set(liveTemporarySpaces),
                    over: runtimePins(of: profile)
                )
                returnHeldSpacesWithoutApply(to: profile)
            }
            profiles.markDirty()
        case .none:
            // A hand-written or hybrid Lua config keeps owning
            // tiling: nothing is adopted, so with no active
            // profile the Lua base survives reloads untouched (#36
            // promise), and Spaces resolve by pin, Main role, then
            // the numbered plan (#3294). A still-active profile
            // keeps its tiling and its pins, numbered on these
            // screens, but goes dirty — the same rule as
            // load_profile onto other hardware.
            guard isGuiManaged else {
                if let active = profiles.active {
                    profiles.markDirty()
                    // Its pins follow its numbers here too (#3647
                    // ▸ lane 2), read from adoption state; a number
                    // past the screens waits.
                    spacePins = keepingPins(
                        of: Set(liveTemporarySpaces),
                        over: liveScreenOrder.runtime(active.screenPins)
                    )
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
                        + "Spaces placed on screens by pin, "
                        + "else by number "
                        + "(tiling stays Lua/profile-owned)"
                )
                return nil
            }
            // On the starter setup baseline, recompose the
            // setup at the live display count instead of a
            // workflow Standard, so the five-per-display shape
            // survives the change (#485). Any other baseline gets
            // the count's built-in Standard, unchanged (#53).
            guard
                let composed = composeMonitorChangeFallback(
                    displays: displays
                )
            else { return nil }
            // `apply(composed:)` adopts the composed placement, so
            // the plan's Spaces land where it put them (not scattered
            // into the resolve's fallback plan), and files the
            // Standard it composed.
            apply(composed: composed, forceRetile: false)
            // Bind ⌃⌥N for spaces the change added past the
            // first-run seed — additive, never overwriting a
            // custom chord (#485).
            topUpDigitShortcuts()
            onLog(
                "monitor change: no matching profile, "
                    + "composed standard '\(composed.sourceName)'"
            )
            composedFallback = StandardFallback(
                screenCount: displays.count
            )
        }
        return composedFallback
    }
}
