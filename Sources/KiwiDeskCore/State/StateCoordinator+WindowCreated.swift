import Foundation

/// The `.windowCreated` fold — placement and initial focus decision (§2.1).
extension StateCoordinator {
    mutating func applyWindowCreated(
        _ window: ManagedWindow,
        effects: inout AppliedEffects
    ) {
        // Forget record to test if window was minimized (#40, #673).
        effects.appearedWasMinimized = forgetMinimized(window.id)
        effects.hadRememberedSpace =
            rememberedSpaces[window.id] != nil
        // Back on a shown Desktop: the away ledger's entry ends
        // (#1146).
        awayWindows[window.id] = nil
        windows.upsert(window)
        restoreFloatOverride(of: window)
        restoreStickyIntent(of: window)
        // Screen wins on multi-monitor Desktop moves (#1010).
        let arrival = arrivalDisplay
        arrivalDisplay = nil
        let owed = returningFocus
        returningFocus = nil
        let remembered = rememberedSpaces[window.id]
        let preferred = arrivalScreenHome(
            of: windows[window.id],
            remembered: remembered,
            arrival: arrival
        )
        effects.rehomedToScreenSpace = preferred
        let target =
            preferred
            ?? livingRememberedSpace(remembered)
            ?? window.appBundleID.flatMap { appRules[$0] }
            ?? workspaces.activeSpace
        guard let target else { return }
        let mode = workspaces[target]?.mode ?? .bsp
        let track =
            mode == .track
            ? (trackParams.override[target]
                ?? TrackOverride())
                .resolved(onto: trackParams)
            : nil
        if let track, !window.isFloating {
            workspaces.add(
                window.id,
                to: target,
                trackRule: track.newWindow,
                trackPosition: track.newWindowPosition,
                spillCapacity: trackCapacities[target],
                trackCap: track.trackCap,
                isTiled: { [windows] id in
                    guard let window = windows[id] else {
                        return false
                    }
                    // Fullscreen window occupies no tiled slot (#670).
                    return !window.isFloating
                        && !window.isFullscreen
                }
            )
        } else if case .departed(target)? = remembered,
            let slot = departedSlots[window.id]
        {
            // A return takes the slot it left, ranked against the
            // members already back (#1207).
            workspaces.add(
                window.id,
                to: target,
                rank: slot,
                ranks: departedSlots
            )
        } else {
            workspaces.add(
                window.id,
                to: target,
                placement: spawnOverride[target]
                    ?? spawnPlacements[mode]
                    ?? .afterFocused
            )
            // Floating window in own_track space gets dormant break marker
            // (#160).
            if track?.newWindow == .ownTrack {
                workspaces.withSpace(target) {
                    $0.trackBreaks.insert(window.id)
                }
            }
        }
        // A RETURNING window joins its space without stealing an
        // existing focus (#636): the re-track burst arrives in
        // arbitrary per-pid order, so the focus REPORT — never
        // re-track order — is the authority. A transient overlay
        // is granted nothing (#300/#671), asked of STATE, not the
        // snapshot (a remembered-tiled restore above may have just
        // cleared it); and it beats the `focused == nil` arm, so
        // an overlay spawning into a focusless space leaves it
        // nil — a popup is not a settle target.
        // A Desktop return's owed window takes the focus when it
        // RETURNS, and while it is still departed no other
        // returning window claims the vacancy (#1207).
        let owedHere =
            owed.map {
                $0 != window.id
                    && rememberedSpaces[$0] == .departed(target)
                    && windows[$0] == nil
            } ?? false
        guard windows[window.id]?.isTransientOverlay != true
        else { return }
        if effects.hadRememberedSpace, owed == window.id,
            target == workspaces.activeSpace
        {
            workspaces.focus(window.id, in: target)
            effects.paidReturningFocus = true
        } else if !effects.hadRememberedSpace
            || (workspaces[target]?.focused == nil && !owedHere)
        {
            workspaces.focus(window.id, in: target)
        }
    }

    /// The remembered Space, unless a DEPARTED window's Space no
    /// longer exists (#1230).
    ///
    /// `workspaces.add` ensures its target, so a window returning
    /// from an away Desktop would silently re-create the Space it
    /// left into a profile that does not declare it — a Space
    /// switching profiles just dropped. Falling through instead
    /// lands it the ordinary way, which is what the profile's
    /// `fallback_space` is for.
    ///
    /// `.restored` is deliberately NOT gated: the session restore
    /// files a window under its Space before that Space is
    /// rebuilt (#1010), so requiring it to exist would strand
    /// every restored window in the active Space instead.
    private func livingRememberedSpace(
        _ remembered: SpaceMemory?
    ) -> SpaceID? {
        guard case .departed(let space)? = remembered else {
            return remembered?.space
        }
        return workspaces[space] == nil ? nil : space
    }

    /// Screen home for arrivals crossing displays (#1010) — the
    /// verdict is `screenHome`'s one copy; what this adds is the
    /// arrival's own gate: a WATCHED DEPARTURE. A `.restored`
    /// memory is KiwiDesk's own filing, never an observed move —
    /// after an undock macOS piles windows onto the built-in
    /// screen, and following THAT frame would discard the very
    /// layout the snapshot exists to put back (#671).
    private func arrivalScreenHome(
        of window: ManagedWindow?,
        remembered: SpaceMemory?,
        arrival: DisplayID?
    ) -> SpaceID? {
        guard let window,
            case .departed(let home)? = remembered
        else { return nil }
        return screenHome(
            of: window,
            leaving: home,
            landingOn: arrival
        )
    }
}
