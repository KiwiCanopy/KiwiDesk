import Foundation

/// `toggle_maximized` (#2448): the focused tiled window, or an
/// effective float (#3036), fills its screen until pressed again,
/// until focus lands on another tiled window of its Space, or until
/// it leaves the tiled set (a float, the float set). A sticky
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
        if monocleRefuses(shape, id, on: space) {
            cueMaximizeRefused(
                id,
                text: L(
                    "maximize.refused.monocle",
                    "Monocle already fills the screen"
                )
            )
            return .fail("monocle already fills the screen")
        }
        if state.handMaximizedWindow(of: space) == id {
            state.workspaces.withSpace(spaceID) {
                if $0.maximized?.shape.matches(shape) == true {
                    $0.maximized = nil
                } else {
                    $0.maximized?.shape = shape
                }
            }
        } else {
            guard spaceID == state.workspaces.activeSpace,
                let follows = maximizeAdmits(id, on: space)
            else {
                cueMaximizeRefused(
                    id,
                    text: L(
                        "maximize.refused.window",
                        "Dialogs, panels, full-screen windows and the "
                            + "Pocket window can't be maximized"
                    )
                )
                return .fail(
                    "a dialog, a panel, a full-screen window or the "
                        + "pocket window cannot be maximized"
                )
            }
            // A press of the shape KiwiVision fills would change
            // nothing on screen (#3064).
            if state.visionFilledWindow(of: space) == id,
                state.maximizedShape(of: space)?.matches(shape) == true
            {
                return refuseVisionFilled(id)
            }
            state.workspaces.withSpace(spaceID) {
                $0.maximized = Maximize(
                    window: id,
                    shape: shape,
                    follows: follows
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

    /// Whether a press may maximize `id` on `space`, and the follow
    /// it stamps: a tile takes the setting's (#3063); an effective
    /// float follows nothing and records the frame it returns to
    /// (#3036). Nil refuses, recording nothing.
    private func maximizeAdmits(_ id: WindowID, on space: Space) -> Bool? {
        if state.placementMode(of: space) != .floating,
            state.effectiveTiledMembers(of: space).contains(id)
        {
            // A record a float left unpaid names no tile's plane.
            state.maximizedFloatReturn[id] = nil
            return tiler.settings.maximize.followFocus
        }
        guard state.mayMaximizeAsFloat(id, on: space),
            let window = state.windows[id]
        else { return nil }
        // A return a held pass still owes is where the window goes
        // back to; its frame now is the fill.
        state.maximizedFloatReturn[id] =
            state.maximizedFloatReturn[id]
            ?? .init(
                pid: window.pid,
                frame: tiler.commandedFrame(of: id) ?? window.frame
            )
        return false
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

    /// A press KiwiVision's fill would hide — a resize, a Maximize of
    /// the shape it fills — refused with its pill, VoiceOver
    /// hearing it too (#3064).
    func refuseVisionFilled(_ window: WindowID) -> CommandResponse {
        flashRefusalPill(
            window,
            text: L(
                "kiwivision.maximize.refused",
                "A window KiwiVision fills keeps its size."
            ),
            symbol: "arrow.up.left.and.arrow.down.right",
            announce: true
        )
        return .fail("a window KiwiVision fills keeps its size")
    }

    /// Whether a Height or Width press on `id` is refused: a tiled
    /// window on a Monocle Space already fills its screen, so the
    /// press would only shrink it into a column (#3090). A float
    /// there may still take one, and a full Maximize is unchanged.
    private func monocleRefuses(
        _ shape: MaximizeShape,
        _ id: WindowID,
        on space: Space
    ) -> Bool {
        shape.axis != nil
            && state.placementMode(of: space) == .monocle
            && state.effectiveTiledMembers(of: space).contains(id)
    }

    /// A refused press's cue: the pill is its only one, so
    /// VoiceOver hears it too (#2480).
    private func cueMaximizeRefused(_ window: WindowID, text: String) {
        flashRefusalPill(
            window,
            text: text,
            symbol: "arrow.up.left.and.arrow.down.right",
            announce: true
        )
    }
}
