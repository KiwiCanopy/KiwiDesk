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
    /// reconcile would fight (#890 ▸ arrival semantics). The Space
    /// is brought into existence here, after the bridge accepted,
    /// so the arrival's `livingRememberedSpace` can honor it.
    func fileExplicitly(
        _ window: WindowID,
        in space: SpaceID,
        target: DesktopTarget
    ) {
        state.workspaces.ensureSpace(space)
        guard target.isCurrent else {
            pendingSpace.record(window, space: space)
            onLog(
                "move_to_desktop: w\(window.raw) will join space "
                    + "\(space.raw) when it departs"
            )
            return
        }
        guard let managed = state.windows[window] else { return }
        let from = state.workspaces.space(of: window)
        guard from != space else { return }
        onLog(
            "move_to_desktop: w\(window.raw) filed into space "
                + "\(space.raw) on the shown Desktop"
        )
        addFocusedToSpace(window, to: space)
        reanchorFloat(window, to: space)
        state.workspaces.focus(window, in: space)
        emitWindowMovedToSpace(
            window,
            app: managed.appName,
            bundleID: managed.appBundleID,
            from: from,
            to: space
        )
        retile(animated: true)
    }
}
