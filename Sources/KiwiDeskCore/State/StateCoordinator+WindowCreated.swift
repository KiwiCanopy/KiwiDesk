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
        windows.upsert(window)
        restoreFloatOverride(of: window)
        restoreStickyIntent(of: window)
        // Screen wins on multi-monitor Desktop moves (#1010).
        let arrival = arrivalDisplay
        arrivalDisplay = nil
        let remembered = rememberedSpaces[window.id]
        let preferred = arrivalScreenHome(
            of: windows[window.id],
            remembered: remembered,
            arrival: arrival
        )
        effects.rehomedToScreenSpace = preferred
        let target =
            preferred
            ?? remembered?.space
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
        // Returning windows do not steal focus; transient overlays never get
        // focus grant (#636, #300, #671).
        if windows[window.id]?.isTransientOverlay != true,
            !effects.hadRememberedSpace
                || workspaces[target]?.focused == nil
        {
            workspaces.focus(window.id, in: target)
        }
    }

    /// Screen home for arrivals crossing displays (#1010, #671).
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
