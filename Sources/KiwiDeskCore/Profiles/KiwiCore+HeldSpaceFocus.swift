import Foundation

/// The focus trackers a held Space's membership move keeps (#1507),
/// split from `KiwiCore+HeldSpaces.swift` for size (§2).
extension KiwiCore {
    /// `WorkspaceManager.add` nils the focus trackers of a window
    /// it moves; the hold is not a focus change.
    func heldFocusTrackers() -> HeldFocus {
        var spaceFocus: [SpaceID: WindowID] = [:]
        for space in state.workspaces.allSpaces {
            spaceFocus[space.id] = space.focused
        }
        return HeldFocus(
            lastFocused: state.workspaces.lastFocused,
            candidate: state.workspaces.focusReturnCandidate,
            spaceFocus: spaceFocus
        )
    }
}

/// The focus trackers a membership move must not cost.
struct HeldFocus {
    let lastFocused: WindowID?
    let candidate: WindowID?
    var spaceFocus: [SpaceID: WindowID]

    func restore(into workspaces: inout WorkspaceManager) {
        workspaces.restoreFocusTrackers(
            lastFocused: lastFocused,
            candidate: candidate,
            spaceFocus: spaceFocus
        )
    }
}
