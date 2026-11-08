import Foundation

/// `toggle_maximized` (#2448): the focused tiled window fills its
/// screen until pressed again, until focus lands on another tiled
/// window of its Space, or until it leaves the tiled set. A sticky
/// window's flag sits on the Space it renders on, so leaving that
/// Space ends it (#3035). The
/// verdict is `StateCoordinator.maximizedWindow(of:)`; the frame
/// is `TilingEngine.fillingMaximized`. A write that rearranges a
/// Space ends its maximize at the write (`Space.releaseScrollSlot`,
/// `resetSizing`, the mode write, `resize`, a profile switch).
extension KiwiCore {
    /// `toggle_maximized([axis, share, anchor])`: no arguments is the
    /// whole screen; an axis fills that one at a share of the other
    /// (#3062). A press of the shape shown ends it, any other shape
    /// changes it in place.
    func toggleMaximized(_ args: [JSONValue] = []) -> CommandResponse {
        let focused = focusedWindowID.flatMap { id in
            state.windows[id].flatMap { window in
                state.renderSpace(of: window).map { (id, $0) }
            }
        }
        let shape: MaximizeShape
        switch maximizeShape(
            from: args,
            for: focused?.1
        ) {
        case .success(let read): shape = read
        case .failure(let refusal): return refusal.response
        }
        guard let focused, let space = state.workspaces[focused.1]
        else { return .fail("no focused window") }
        let (id, spaceID) = focused
        if state.maximizedWindow(of: space) == id {
            state.workspaces.withSpace(spaceID) {
                if $0.maximized?.shape.matches(shape) == true {
                    $0.maximized = nil
                } else {
                    $0.maximized?.shape = shape
                }
            }
        } else {
            guard space.mode != .floating,
                spaceID == state.workspaces.activeSpace,
                state.effectiveTiledMembers(of: space).contains(id)
            else {
                cueMaximizeRefused(id)
                return .fail("only a tiled window can be maximized")
            }
            state.workspaces.withSpace(spaceID) {
                $0.maximized = Maximize(
                    window: id,
                    shape: shape,
                    follows: tiler.settings.maximize.followFocus
                )
            }
        }
        retileEndingMaximize([id])
        if state.workspaces[spaceID]?.maximized?.window == id {
            raiseWindow(id)
            raiseFloatsAbove(afterFocusing: id)
        }
        return .ok()
    }

    /// Whether `space` lays every tiled member at its screen's whole
    /// visible frame: Monocle's "Maximize windows" (#2976).
    func maximizesWindows(of space: Space) -> Bool {
        tiler.settings.maximizesWindows(in: space.mode)
    }

    /// The windows of `space` the ring and the marks step aside on as
    /// filling their screen: a full Maximize (#2448, not a Height or
    /// Width one, #3062) and the tiled members of a maximizing
    /// Monocle or of a Monocle a full follow draws whole (#3063).
    func screenFillers(of space: Space) -> Set<WindowID> {
        var fillers: Set<WindowID> = []
        if state.maximizedShape(of: space)?.axis == nil,
            let id = state.maximizedWindow(of: space)
        {
            fillers.insert(id)
        }
        if maximizesWindows(of: space) || state.monocleFollowFills(space) {
            fillers.formUnion(state.effectiveTiledMembers(of: space))
        }
        return fillers
    }

    /// The pass that grows a window to its screen or puts it back:
    /// one already-placed window changes size in place, no slot or
    /// membership moving, so it promises spring sizing (#593);
    /// `windows` are the state change and follow their own switch
    /// (#2676), the pass the resize animation's.
    func retileEndingMaximize(_ windows: Set<WindowID>) {
        retile(
            animated: tiler.settings.animations.onWindowResize,
            sizing: .allSpringSized,
            stateChange: windows
        )
    }

    /// Ends the maximize `window` holds, if any, ahead of a drag
    /// of it; the drop's pass places it. Bars and rings return now.
    @discardableResult
    func endMaximize(of window: WindowID) -> Bool {
        guard let spaceID = state.windows[window].flatMap(state.renderSpace),
            state.workspaces[spaceID]?.maximized?.window == window
        else { return false }
        state.workspaces.withSpace(spaceID) { $0.maximized = nil }
        updateBars()
        updateBorders()
        updateMarks()
        return true
    }

    /// A refused press's cue: the pill is its only one, so
    /// VoiceOver hears it too (#2480).
    private func cueMaximizeRefused(_ window: WindowID) {
        flashRefusalPill(
            window,
            text: L(
                "maximize.refused.floating",
                "Only a tiled window can be maximized."
            ),
            symbol: "arrow.up.left.and.arrow.down.right",
            announce: true
        )
    }
}
