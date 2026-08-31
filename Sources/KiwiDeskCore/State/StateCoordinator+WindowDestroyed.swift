import Foundation

/// Event fold for window destruction lifecycle events (#670).
extension StateCoordinator {
    mutating func applyWindowDestroyed(
        _ id: WindowID,
        wasMinimized: Bool,
        effects: inout AppliedEffects
    ) {
        effects.removedWindow = removalFacts(id)
        if wasMinimized {
            rememberedSpaces[id] = nil
            // Before `windows.remove(id)` below: the record needs
            // the snapshot's pid and bundle id (#673).
            rememberMinimized(id)
        } else if let space = workspaces.space(of: id) {
            // `.departed`: this fold WATCHED it go, which is what
            // the #1010 arrival rule asks for.
            rememberedSpaces[id] = .departed(space)
        }
        // Float intent is remembered even for minimized windows:
        // deminiaturize re-tracks from detection and would lose a
        // manual override too (#160).
        if let window = windows[id] {
            rememberFloatOverride(of: window)
            rememberStickyIntent(of: window)
        }
        let home = workspaces.space(of: id)
        let heldFocus =
            home.map { workspaces[$0]?.focused == id }
            ?? false
        let slot = home.flatMap {
            workspaces[$0]?.windows.firstIndex(of: id)
        }
        windows.remove(id)
        workspaces.remove(id)
        // Close-return: hand focus back to the window the user
        // was in just before — ONE visible step of history, not
        // the spatial successor, and NOT the repeat-press MRU
        // cycling #637 rejected (`docs/design-decisions.md` ▸
        // Close-return focus). Only a candidate still surfaceable
        // in the SAME space: alive, in `home`, not
        // native-fullscreen (#670 — the raise would switch
        // Spaces), not a transient overlay (#671). Invalid falls
        // through to `Space.remove`'s successor-slot pick.
        if heldFocus, let home,
            let candidate = workspaces.focusReturnCandidate,
            workspaces.space(of: candidate) == home,
            windows[candidate]?.isFullscreen == false,
            windows[candidate]?.isTransientOverlay == false
        {
            workspaces.withSpace(home) {
                $0.focused = candidate
            }
        }
        // The slot-neighbor fallback can land on a fullscreen
        // member (#670 review): re-pick the nearest surfaceable
        // one — forward from the removed slot first, matching
        // `Space.remove`'s own direction, then backward; never
        // the array head (the #11 yank).
        if heldFocus, let home,
            let picked = workspaces[home]?.focused,
            windows[picked]?.isFullscreen == true,
            let members = workspaces[home]?.windows
        {
            let start = min(
                slot ?? members.count,
                members.count
            )
            let next =
                members[start...].first {
                    windows[$0]?.isFullscreen == false
                }
                ?? members[..<start].reversed().first {
                    windows[$0]?.isFullscreen == false
                }
            workspaces.withSpace(home) { $0.focused = next }
        }
    }
}
