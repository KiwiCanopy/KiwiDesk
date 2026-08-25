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
        // Dropping the record IS the "was this minimized?" test
        // (#40/#673) — one container, so the answer cannot drift
        // from the thing it is derived from. Unconditional, so a
        // recycled `CGWindowID` cannot inherit a dead window's
        // record either.
        effects.appearedWasMinimized = forgetMinimized(window.id)
        effects.hadRememberedSpace =
            rememberedSpaces[window.id] != nil
        windows.upsert(window)
        restoreFloatOverride(of: window)
        restoreStickyIntent(of: window)
        // SCREEN WINS (#1010). A window that comes back on a
        // display OTHER than the one its remembered space lays
        // out on was carried across screens while it was away —
        // `move_to_desktop` onto another screen's Desktop, or the
        // same gesture in Mission Control. The Desktop the user
        // just chose is the more recent intent, so the arrival
        // takes the space that display shows. Without this the
        // retile carries the window back to the remembered
        // space's screen and macOS re-assigns its Desktop to
        // match the frame, undoing the move a second after the
        // Desktop is revealed. The ruling — and why the two
        // alternatives lost — is `docs/design-decisions.md`'s.
        //
        // Only the window's MEMBERSHIP moves; no space is
        // re-assigned, so a `pin_space_to_display` pin is never
        // violated (#890 owns the wider per-screen questions),
        // a `.display` sticky keeps #445's derived home display,
        // and nothing is owed the float re-anchor (#444) — the
        // membership follows the frame here, so there is no
        // cross-display translation to make.
        let remembered = rememberedSpaces[window.id]
        let preferred = screenHome(for: remembered)
        effects.rehomedToScreenSpace = preferred
        let target =
            preferred
            ?? remembered
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
                    // A fullscreen member occupies no slot
                    // (#670): it left the tiled derivations,
                    // so fill-then-spill must not count it.
                    return !window.isFloating
                        && !window.isFullscreen
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

    /// The space an arrival prefers over the one it remembered,
    /// when its own screen disagrees with that space's (#1010):
    /// the space the arrival's display currently shows.
    ///
    /// Nil — leaving the resolution exactly as it was — when the
    /// window did not come back (no remembered space, the fold's
    /// `hadRememberedSpace` gate), when no screen backs its
    /// frame, when the remembered space is assigned to no display
    /// yet (early boot, unit fixtures), when the two sit on the
    /// SAME display, which is every single-screen arrival, and
    /// when the arrival's display shows nothing.
    private func screenHome(for remembered: SpaceID?) -> SpaceID? {
        guard let remembered,
            let arrival = arrivalDisplay,
            let home = workspaces.display(of: remembered),
            home != arrival
        else { return nil }
        return workspaces.activeSpace(on: arrival)
    }
}
