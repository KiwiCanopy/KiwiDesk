import Foundation

/// `toggle_maximized` (#2448): the focused tiled window fills its
/// screen until pressed again, until focus lands on another tiled
/// window of its Space, or until it leaves the tiled set. The
/// verdict is `StateCoordinator.maximizedWindow(of:)`; the frame
/// is `TilingEngine.fillingMaximized`.
extension KiwiCore {
    /// The verbs that change a Space's arrangement: each ends the
    /// active Space's maximize before it acts, so it never moves a
    /// slot nobody can see.
    static let maximizeEndingVerbs: Set<String> = [
        "swap", "swap_here", "resize", "move_to_track", "track.swap",
        "stack.promote", "stack.demote", "set_mode", "cycle_mode",
        "reset_layout_sizing",
    ]

    func toggleMaximized() -> CommandResponse {
        guard let id = focusedWindowID,
            let spaceID = state.workspaces.space(of: id),
            let space = state.workspaces[spaceID]
        else { return .fail("no focused window") }
        if state.maximizedWindow(of: space) == id {
            state.workspaces.withSpace(spaceID) { $0.maximized = nil }
        } else {
            guard space.mode != .floating,
                state.localTiledMembers(of: space).contains(id)
            else { return .fail("not a tiled window") }
            state.workspaces.withSpace(spaceID) { $0.maximized = id }
        }
        // One window grows or shrinks in place; no slot moves.
        retile(sizing: .allSpringSized)
        if state.workspaces[spaceID]?.maximized == id {
            raiseWindow(id)
        }
        return .ok()
    }

    /// Ends the active Space's maximize ahead of a verb that
    /// rearranges it (`maximizeEndingVerbs`); the verb's own
    /// retile places the window back in its slot.
    func endMaximizeAhead(of command: String) {
        guard Self.maximizeEndingVerbs.contains(command),
            let spaceID = state.workspaces.activeSpace,
            state.workspaces[spaceID]?.maximized != nil
        else { return }
        state.workspaces.withSpace(spaceID) { $0.maximized = nil }
    }

    /// Retires every maximize its verdict no longer honours — a
    /// focus moved onto another tiled member — and retiles the
    /// window back into its slot. Called after a focus write.
    func settleMaximizeAfterFocus() {
        guard !state.retireEndedMaximize().isEmpty else { return }
        retile(sizing: .allSpringSized)
    }
}
