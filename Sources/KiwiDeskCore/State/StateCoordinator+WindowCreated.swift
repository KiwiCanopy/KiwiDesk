import Foundation

/// The `.windowCreated` fold — placement (track rule / spawn
/// placement / dormant break marker) and the focus decision.
/// Split from `StateCoordinator.apply` for the file ceiling
/// (§2.1), like `+Intents` and `+EffectiveMembers`.
extension StateCoordinator {
    mutating func applyWindowCreated(
        _ window: ManagedWindow,
        effects: inout AppliedEffects
    ) {
        effects.appearedWasMinimized =
            minimizedWindows.remove(window.id) != nil
        // Unconditional, not only on a deminiaturize: a recycled
        // `CGWindowID` must not inherit a dead window's minimize
        // record (#673).
        forgetMinimized(window.id)
        effects.hadRememberedSpace =
            rememberedSpaces[window.id] != nil
        windows.upsert(window)
        restoreFloatOverride(of: window)
        restoreStickyIntent(of: window)
        let target =
            rememberedSpaces[window.id]
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
                isTiled: { [windows] in
                    windows[$0]?.isFloating == false
                }
            )
        } else {
            workspaces.add(
                window.id,
                to: target,
                placement: spawnOverride[target]
                    ?? spawnPlacements[mode]
                    ?? .afterFocused
            )
            // A floating window spawned into an `own_track`
            // space carries a dormant break marker, matching
            // what the mode-entry seed gives every window
            // (`setMode`): when a float re-check heals it to
            // tiled (#160), it opens its own track at its slot
            // instead of silently merging into its array
            // neighbor's track. `focused_track` stays
            // markerless — joining by position is that rule's
            // meaning.
            if track?.newWindow == .ownTrack {
                workspaces.withSpace(target) {
                    $0.trackBreaks.insert(window.id)
                }
            }
        }
        // A RETURNING window (remembered space — a
        // native-switch re-track, wake restore, app relaunch)
        // joins its space without stealing an existing focus
        // (#636): the re-track burst arrives in arbitrary
        // per-pid order, so the last-created window won the
        // ring while the OS had focused another — the focus
        // report, not re-track order, is the authority. A
        // fresh spawn (or deminiaturize, which clears the
        // memory) still takes focus, and so does the first
        // returner into a space whose members all left with
        // it (`focused == nil`) — the settle fallback needs a
        // target even when no focus report ever arrives.
        //
        // A TRANSIENT OVERLAY is granted nothing here — only the
        // GRANT, never the slot, and the argument for stopping
        // exactly there is the #300 entry in
        // `docs/design-decisions.md` (#671).
        //
        // Two things it does not say, both local to this fold.
        // The flag is asked of STATE, not of the incoming
        // snapshot: a remembered-tiled restore above clears it
        // (`setFloating`), and such a window is ordinary again.
        // And this beats the `focused == nil` arm above, so an
        // overlay spawning into a space with no focus leaves it
        // nil — which is the wanted answer (a popup is not a
        // settle target) at the price of a space that reports no
        // focused window until a real one arrives, or a space
        // switch re-seeds it.
        if windows[window.id]?.isTransientOverlay != true,
            !effects.hadRememberedSpace
                || workspaces[target]?.focused == nil
        {
            workspaces.focus(window.id, in: target)
        }
    }
}
