import Foundation

/// The composed `space:` target's two routes (#1150) — split from
/// `KiwiCore+DesktopMove.swift` at the §2.1 target; the verb's
/// parse stays in `KiwiCore+DesktopCommands.swift`.
extension KiwiCore {
    /// Files the focused window into the Space the user named,
    /// split by the same gate as the screen-home rule
    /// (`rehomeAcrossScreens`). A Desktop its screen ALREADY shows
    /// produces no departure, so the window is filed NOW — the
    /// re-home's own steps with the user's Space in place of the
    /// shown one, plus the float re-anchor `moveWindow` carries
    /// (#444). A HIDDEN Desktop is the arrival's: the name is
    /// recorded and paid at the departure (`PendingSpaceAssignment`),
    /// never written into the membership here, which the reveal
    /// reconcile would fight (#890 ▸ arrival semantics). Neither
    /// route creates the Space here: the shown one's filing does,
    /// and the hidden one's CLAIM does at the departure, so an
    /// expired name leaves no empty Space behind.
    func fileExplicitly(
        _ window: WindowID,
        in space: SpaceID,
        target: DesktopTarget
    ) {
        guard target.isCurrent else {
            pendingSpace.record(window, space: space)
            onLog(
                "move_to_desktop: w\(window.raw) will join space "
                    + "\(space.raw) when it departs"
            )
            return
        }
        guard state.windows[window] != nil else { return }
        let from = state.workspaces.space(of: window)
        guard from != space else { return }
        onLog(
            "move_to_desktop: w\(window.raw) filed into space "
                + "\(space.raw) on the shown Desktop"
        )
        fileMembership(window, into: space, from: from)
        retile(animated: true)
    }
}
