import Foundation

/// Repeat presses of Open or Focus cycle the app's windows
/// (#637): when `pull_or_spawn` fires while one of the target
/// app's windows is already focused, the shortcut advances to
/// the app's next window — space order, then slot order,
/// wrapping — instead of re-activating an app that is already
/// forward (which did nothing visible).
///
/// Since #1146 the ring also holds the app's windows UP on
/// Desktops nobody shows, by the rank they will return in, and
/// cycling onto one REACHES it over the bridge
/// (`KiwiCore+LaunchReach`). Without the bridge the ring is the
/// tracked windows alone.
extension KiwiCore {
    /// The already-focused branch of `pull_or_spawn`. Returns
    /// `false` when cycling does not apply — the focused window
    /// is not this app's, the app is not the frontmost one, or
    /// it has fewer than two windows in the ring — so the caller
    /// falls through to the plain activate. `bundleID` arrives
    /// lowercased (the command's normalization).
    func cycleToNextWindow(bundleID: String) -> Bool {
        guard
            let current = state.workspaces.lastFocused,
            let window = state.windows[current],
            window.appBundleID?.lowercased() == bundleID,
            // OS truth, not just our state: after a cmd-tab
            // away, the stale state focus must not turn a
            // "bring it back" press into a surprise cycle.
            frontmostPIDProvider?() == window.pid
        else { return false }
        let reach = canDriveDesktops ? awayReach(bundleID: bundleID) : nil
        let ring = cycleRing(
            bundleID: bundleID,
            away: Set(reach?.windows.map(\.window.id) ?? [])
        )
        guard ring.count > 1,
            let index = ring.firstIndex(of: current)
        else { return false }
        return focusCycleTarget(ring[(index + 1) % ring.count], reach: reach)
    }

    /// Every window of the app in cycle order: spaces in their
    /// canonical order, each space's row within — present
    /// members and the UP away ones in `away`, by rank.
    /// Deterministic, so repeat presses walk a stable ring.
    /// Transient overlays (a launcher's panel, #300) are not in
    /// it: they exist momentarily, never wear a ring, and are
    /// not "the app's windows" in the user's mental model.
    private func cycleRing(
        bundleID: String,
        away: Set<WindowID>
    ) -> [WindowID] {
        state.workspaces.allSpaces.flatMap { space in
            withAwayMembers(space.windows, of: space.id).filter { id in
                if let window = state.windows[id] {
                    return window.appBundleID?.lowercased() == bundleID
                        && !window.isTransientOverlay
                }
                return away.contains(id)
            }
        }
    }

    /// Focuses the cycle's successor. A same-space target is a
    /// plain focus; one on another Space switches the
    /// way a follow move does (`followSwitch`). A STICKY
    /// target never switches (#414): its membership names only
    /// its hidden home space while the window renders right
    /// here — the same fly-back `scheduleFocusFollow` refuses.
    /// An AWAY target is reached (#1146); a refused reach leaves
    /// the press to the plain activate.
    private func focusCycleTarget(
        _ id: WindowID,
        reach: AwayReach?
    ) -> Bool {
        if let reach,
            let entry = reach.windows.first(where: { $0.window.id == id })
        {
            return reachAwayWindow(
                entry.window,
                desktop: entry.desktop,
                snapshot: reach.snapshot,
                verb: "pull_or_spawn"
            )
        }
        guard
            let space = state.workspaces.space(of: id),
            space != state.workspaces.activeSpace,
            state.windows[id]?.isSticky != true
        else {
            focusWindow(id, warp: true)
            return true
        }
        followSwitch(to: space, focusing: id)
        return true
    }
}
