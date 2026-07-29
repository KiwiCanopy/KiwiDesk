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
    /// ring.
    private func trackedWindows(
        bundleID: String
    ) -> [WindowID] {
        state.workspaces.allSpaces.flatMap { space in
            space.windows.filter {
                state.windows[$0]?.appBundleID?.lowercased()
                    == bundleID
            }
        }
    }

    /// Focuses the cycle's successor. A same-space target is a
    /// plain focus; one on another virtual space switches the
    /// way a follow move does (`moveWindow(follow: true)`):
    /// activate, focus without the redundant retile, then the
    /// coordinated switch retile owns placement.
    private func focusCycleTarget(_ id: WindowID) {
        guard
            let space = state.workspaces.space(of: id),
            space != state.workspaces.activeSpace
        else {
            focusWindow(id, warp: true)
            return
        }
        // Captured before the raise below can change it — the
        // settle's dropped-activate detection (#463 pattern).
        let priorFrontmost = frontmostPIDProvider?()
        state.workspaces.activate(space)
        focusWindow(id, refocusRetile: false, warp: true)
        emitSpaceChange()
        scheduleSpaceSettle(
            space,
            priorFrontmost: priorFrontmost
        )
        spaceSwitchRetile()
    }
}
