import Foundation

/// Repeat presses of Open or Focus cycle the app's windows
/// (#637): when `pull_or_spawn` fires while one of the target
/// app's windows is already focused, the shortcut advances to
/// the app's next tracked window — space order, then slot
/// order, wrapping — instead of re-activating an app that is
/// already forward (which did nothing visible).
///
/// The cycle only covers windows KiwiDesk currently tracks:
/// windows on other native desktops are untracked while away
/// (AX cannot see them, #25), so those still go through the
/// plain activate, which lets macOS pull its desktop forward.
extension KiwiCore {
    /// The already-focused branch of `pull_or_spawn`. Returns
    /// `false` when cycling does not apply — the focused window
    /// is not this app's, the app is not the frontmost one, or
    /// it has fewer than two tracked windows — so the caller
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
        let ring = trackedWindows(bundleID: bundleID)
        guard ring.count > 1,
            let index = ring.firstIndex(of: current)
        else { return false }
        focusCycleTarget(ring[(index + 1) % ring.count])
        return true
    }

    /// Every tracked window of the app, in cycle order: spaces
    /// in their canonical order, each space's flat array order
    /// within. Deterministic, so repeat presses walk a stable
    /// ring. Transient overlays (a launcher's panel, #300) are
    /// not in it: they exist momentarily, never wear a ring,
    /// and are not "the app's windows" in the user's mental
    /// model of the cycle.
    private func trackedWindows(
        bundleID: String
    ) -> [WindowID] {
        state.workspaces.allSpaces.flatMap { space in
            space.windows.filter { id in
                guard let window = state.windows[id] else {
                    return false
                }
                return window.appBundleID?.lowercased()
                    == bundleID
                    && !window.isTransientOverlay
            }
        }
    }

    /// Focuses the cycle's successor. A same-space target is a
    /// plain focus; one on another Space switches the
    /// way a follow move does (`followSwitch`). A STICKY
    /// target never switches (#414): its membership names only
    /// its hidden home space while the window renders right
    /// here — the same fly-back `scheduleFocusFollow` refuses.
    private func focusCycleTarget(_ id: WindowID) {
        guard
            let space = state.workspaces.space(of: id),
            space != state.workspaces.activeSpace,
            state.windows[id]?.isSticky != true
        else {
            focusWindow(id, warp: true)
            return
        }
        followSwitch(to: space, focusing: id)
    }
}
