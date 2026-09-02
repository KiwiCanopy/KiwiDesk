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
            rememberMinimized(id)
        } else if let space = workspaces.space(of: id) {
            rememberedSpaces[id] = .departed(space)
            rememberDepartedSlot(of: id, in: space)
        }
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
        // Close-return focus restore for non-fullscreen/transient windows
        // (`Space.remove`, `docs/design-decisions.md`, #637, #670, #671).
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
        // Slot neighbor fallback skipping fullscreen members (#11, #670).
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
