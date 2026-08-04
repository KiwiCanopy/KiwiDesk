import Foundation

/// The `.windowDestroyed` fold — the minimize/space memory, the
/// removal, and the two focus picks that follow it (close-return
/// and the #670 fullscreen re-pick). Split from
/// `StateCoordinator.apply` for the file ceiling (§2.1), like
/// `+WindowCreated`.
extension StateCoordinator {
    mutating func applyWindowDestroyed(
        _ id: WindowID,
        wasMinimized: Bool,
        effects: inout AppliedEffects
    ) {
        effects.removedWindow = removalFacts(id)
        if wasMinimized {
            rememberedSpaces[id] = nil
            // Before `windows.remove(id)` below: the record
            // needs the snapshot's pid and bundle id (#673).
            rememberMinimized(id)
        } else if let space = workspaces.space(of: id) {
            rememberedSpaces[id] = space
        }
        // Float intent is remembered even for minimized
        // windows: deminiaturize re-tracks from detection
        // and would lose a manual override too (#160).
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
        // Close-return: when THIS close moved the focus,
        // hand it back to the window the user was in just
        // before — one visible step of history, not the
        // spatial successor. Only when the candidate is
        // still a surfaceable member of the SAME space at
        // close time: alive (a dead or minimized candidate
        // is simply absent from state), still in `home`
        // (never a cross-space yank), not native-fullscreen
        // (#670 — the raise would switch Spaces), and not a
        // transient overlay (#671 — no resurrecting a focus
        // nobody granted). An invalid candidate falls
        // through to the successor-slot pick `Space.remove`
        // already made. This is a single step back, NOT the
        // repeat-press MRU cycling #637 rejected — the
        // argument lives in `docs/design-decisions.md`
        // ▸ Close-return focus.
        if heldFocus, let home,
            let candidate = workspaces.previousFocused,
            workspaces.space(of: candidate) == home,
            windows[candidate]?.isFullscreen == false,
            windows[candidate]?.isTransientOverlay == false
        {
            workspaces.withSpace(home) {
                $0.focused = candidate
            }
        }
        // The slot-neighbor fallback can land on a
        // fullscreen member (#670 review): the close
        // handler's raise would then switch the user to
        // its Space. Only when THIS close moved the focus
        // (a fullscreen slot held before the close stays
        // held), re-pick the nearest surfaceable member —
        // forward from the removed slot first, matching
        // `Space.remove`'s own direction, then backward;
        // never the array head (the #11 yank).
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
