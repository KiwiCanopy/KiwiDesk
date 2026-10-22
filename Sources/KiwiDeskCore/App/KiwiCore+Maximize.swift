import Foundation

/// `toggle_maximized` (#2448): the focused tiled window fills its
/// screen until pressed again, until focus lands on another tiled
/// window of its Space, or until it leaves the tiled set. The
/// verdict is `StateCoordinator.maximizedWindow(of:)`; the frame
/// is `TilingEngine.fillingMaximized`. A write that rearranges a
/// Space ends its maximize at the write (`Space.releaseScrollSlot`,
/// `resetSizing`, the mode write, `resize`, a profile switch).
extension KiwiCore {
    func toggleMaximized() -> CommandResponse {
        guard let id = focusedWindowID,
            let spaceID = state.workspaces.space(of: id),
            let space = state.workspaces[spaceID]
        else { return .fail("no focused window") }
        if state.maximizedWindow(of: space) == id {
            state.workspaces.withSpace(spaceID) { $0.maximized = nil }
        } else {
            // A sticky window draws on other Spaces' layouts too,
            // so only a plain tiled member of its own Space fills.
            guard state.windows[id]?.isSticky == false else {
                cueMaximizeRefused(id, sticky: true)
                return .fail("a sticky window")
            }
            guard space.mode != .floating,
                spaceID == state.workspaces.activeSpace,
                state.localTiledMembers(of: space).contains(id)
            else {
                cueMaximizeRefused(id, sticky: false)
                return .fail("not a tiled window")
            }
            state.workspaces.withSpace(spaceID) { $0.maximized = id }
        }
        retileEndingMaximize()
        if state.workspaces[spaceID]?.maximized == id {
            raiseWindow(id)
            raiseFloatsAbove(afterFocusing: id)
        }
        return .ok()
    }

    /// The pass that grows a window to its screen or puts it back:
    /// one already-placed window changes size in place, no slot or
    /// membership moving, so it promises spring sizing (#593), on
    /// the resize animation's own switch.
    func retileEndingMaximize() {
        retile(
            animated: tiler.settings.animations.onWindowResize,
            sizing: .allSpringSized
        )
    }

    /// Ends the maximize `window` holds, if any, ahead of a drag
    /// of it; the drop's pass places it. Bars and rings return now.
    @discardableResult
    func endMaximize(of window: WindowID) -> Bool {
        guard let spaceID = state.workspaces.space(of: window),
            state.workspaces[spaceID]?.maximized == window
        else { return false }
        state.workspaces.withSpace(spaceID) { $0.maximized = nil }
        updateBars()
        updateBorders()
        updateMarks()
        return true
    }

    /// A refused press's cue: the pill is its only one, so
    /// VoiceOver hears it too (#2480).
    private func cueMaximizeRefused(_ window: WindowID, sticky: Bool) {
        flashRefusalPill(
            window,
            text: sticky
                ? L(
                    "maximize.refused.sticky",
                    "A sticky window can't be maximized."
                )
                : L(
                    "maximize.refused.floating",
                    "Only a tiled window can be maximized."
                ),
            symbol: "arrow.up.left.and.arrow.down.right",
            announce: true
        )
    }
}
