import Foundation

/// Which window a Space shows maximized (#2448). The stored
/// `Space.maximized` is the toggle; this verdict is what every
/// reader takes, since the maximize ends the moment its window
/// leaves the tiled set (a float's, the float set, #3036) or focus
/// lands on another tiled member. KiwiVision's derived fill answers
/// where no toggle stands (#3064).
extension StateCoordinator {
    /// The window `space` shows filling its screen, or nil: a hand
    /// Maximize, else KiwiVision's fill (#3064).
    public func maximizedWindow(of space: Space) -> WindowID? {
        handMaximizedWindow(of: space) ?? visionFilledWindow(of: space)
    }

    /// The window a hand Maximize fills on `space`, or nil: the
    /// stored `Space.maximized` while that window is drawn tiled
    /// on a tiled layout, a traveler included, and the Space's
    /// focus anchor is on it, or on a window the layout draws no
    /// slot for (a float). A traveler is never `space.focused`
    /// (#431), so it asks the system focus itself, and focus on
    /// another screen keeps it (#3035).
    /// A float's Maximize (#3036) stands while the window is an
    /// effective float `space` draws, holding a return frame, and
    /// no tiled member of `space` holds focus.
    public func handMaximizedWindow(of space: Space) -> WindowID? {
        guard let id = space.maximized?.window,
            let tiled = maximizedTiled(of: space)
                ?? maximizedFloatPlane(of: space),
            maximizeRival(of: space, window: id, tiled: tiled) == nil
        else { return nil }
        return id
    }

    /// `space`'s tiled members while its stored Maximize window is
    /// an effective float it draws (#3036), or nil: none on a
    /// floating layout, so focus never ends it there.
    private func maximizedFloatPlane(of space: Space) -> [WindowID]? {
        guard let id = space.maximized?.window,
            maximizesAsFloat(id, on: space)
        else { return nil }
        return placementMode(of: space) == .floating
            ? [] : effectiveTiledMembers(of: space)
    }

    /// Whether `id` stands maximized as a float of `space` (#3036):
    /// `mayMaximizeAsFloat` with its return record written.
    func maximizesAsFloat(_ id: WindowID, on space: Space) -> Bool {
        maximizedFloatReturn[id] != nil
            && mayMaximizeAsFloat(id, on: space)
    }

    /// Whether a press may maximize `id` as a float of `space`, read
    /// without writing (#3036): an effective float drawn there,
    /// never native full screen, a transient overlay or the
    /// pocket's window, whose frames are the pocket's.
    func mayMaximizeAsFloat(_ id: WindowID, on space: Space) -> Bool {
        guard let window = windows[id],
            !window.isFullscreen, !window.isTransientOverlay,
            pocketSlot(of: id) == nil,
            renderSpace(of: window) == space.id
        else { return false }
        return EffectiveFloat.applies(
            isFloating: window.isFloating,
            mode: placementMode(of: space)
        )
    }

    /// The return frames no Maximize holds any longer (#3036): a
    /// tracked window no Space's stored Maximize names. A window
    /// not tracked keeps its record — a Desktop departure's
    /// Maximize stands, a minimize returns to the frame — until
    /// `forgetFloatMemory` ends it.
    func owedMaximizedFloatReturns() -> [WindowID: FloatFrame] {
        let held = Set(workspaces.allSpaces.compactMap(\.maximized?.window))
        return maximizedFloatReturn.filter {
            windows[$0.key] != nil && !held.contains($0.key)
        }
    }

    /// `space`'s tiled members while its stored Maximize window is
    /// drawn tiled on a tiled layout, or nil. A float's Maximize is
    /// no tile's once the window tiles: its return record ends it.
    private func maximizedTiled(of space: Space) -> [WindowID]? {
        guard let id = space.maximized?.window,
            placementMode(of: space) != .floating,
            maximizedFloatReturn[id] == nil
        else { return nil }
        let tiled = effectiveTiledMembers(of: space)
        return tiled.contains(id) ? tiled : nil
    }

    /// The other tiled member of `space` holding focus over `window`,
    /// which ends a Maximize or, while it follows, takes it (#3063).
    private func maximizeRival(
        of space: Space,
        window id: WindowID,
        tiled: [WindowID]
    ) -> WindowID? {
        let rival =
            space.windows.contains(id)
            ? focusAnchor(of: space, tiled: tiled)
            : workspaces.lastFocused
        guard let rival, rival != id, tiled.contains(rival) else {
            return nil
        }
        return rival
    }

    /// `space`'s maximized window where it stands as a float, the
    /// float tier's (#3036), or nil: the one answer of which plane a
    /// Maximize is on, since a tile's holds no return record.
    public func maximizedFloat(of space: Space) -> WindowID? {
        handMaximizedWindow(of: space).flatMap {
            maximizedFloatReturn[$0] == nil ? nil : $0
        }
    }

    /// What `space`'s maximized window fills (#3062), or nil where
    /// `maximizedWindow(of:)` shows none.
    public func maximizedShape(of space: Space) -> MaximizeShape? {
        if handMaximizedWindow(of: space) != nil {
            return space.maximized?.shape
        }
        return visionFilledWindow(of: space) == nil
            ? nil : visionFillShape(of: space)
    }

    /// The maximized traveler drawn beneath `id`, on the Space `id`
    /// renders on, which focus returns to if `id` holds it and
    /// closes (#3035). A member's hand-back is `Space.remove`'s.
    func maximizedTraveler(beneath id: WindowID) -> WindowID? {
        guard let window = windows[id],
            let space = renderSpace(of: window).flatMap({ workspaces[$0] }),
            let traveler = maximizedWindow(of: space), traveler != id,
            !space.windows.contains(traveler)
        else { return nil }
        return traveler
    }

    /// Whether `id`'s maximize waits for its return: no longer
    /// tracked, remembered as departed from `space` and not marked
    /// closed — a Desktop departure, a hide or a Desktop move verb
    /// alike (#2448). Not `KiwiCore.departedWithDesktop`, the
    /// compositor-confirmed vanish.
    func awaitsMaximizedReturn(_ id: WindowID, from space: SpaceID) -> Bool {
        windows[id] == nil
            && rememberedSpaces[id] == .departed(space)
            && !closedDepartures.contains(id)
    }

    /// Clears every stored maximize the verdict no longer honours,
    /// so focus coming back never re-maximizes, and re-points a
    /// following one at the tiled window focus moved to (#3063).
    /// Returns the windows whose size it changed: an ended one, a
    /// follow's window left and window arriving, and KiwiVision's
    /// (`retireVisionFill`, #3064).
    @discardableResult
    mutating func retireEndedMaximize() -> [WindowID] {
        var changed: [WindowID] = []
        for space in workspaces.allSpaces {
            guard let maximize = space.maximized,
                handMaximizedWindow(of: space) == nil,
                !awaitsMaximizedReturn(maximize.window, from: space.id)
            else { continue }
            let rival =
                maximize.follows
                ? maximizedTiled(of: space).flatMap {
                    maximizeRival(
                        of: space,
                        window: maximize.window,
                        tiled: $0
                    )
                } : nil
            workspaces.withSpace(space.id) {
                if let rival {
                    $0.maximized?.window = rival
                } else {
                    $0.maximized = nil
                }
            }
            changed.append(maximize.window)
            if let rival { changed.append(rival) }
        }
        return changed + retireVisionFill()
    }

    /// Whether `space` is a Monocle showing a full Maximize that
    /// follows focus, which every member draws at the full frame
    /// (#3063 ▸ 4).
    public func monocleFollowFills(_ space: Space) -> Bool {
        space.mode == .monocle && followsMaximize(of: space)
            && maximizedShape(of: space)?.axis == nil
    }

    /// Whether `space` shows a Maximize that follows focus (#3063).
    public func followsMaximize(of space: Space) -> Bool {
        handMaximizedWindow(of: space) != nil
            && space.maximized?.follows == true
    }

    /// Whether a focus on `space` re-points a maximize: a hand
    /// Maximize that follows focus (#3063) or KiwiVision's fill
    /// (#3064).
    public func maximizeFollowsFocus(on space: Space) -> Bool {
        followsMaximize(of: space) || visionFillStands(on: space)
    }

    /// A copy with every maximize a focus on `space` would re-point
    /// dropped — what a check of a focus's own layout motion
    /// compares, since that maximize follows the focus by ruling
    /// (#3177). A hand Maximize that ends on focus stays.
    func droppingFocusFollowers(on space: SpaceID) -> StateCoordinator {
        var copy = self
        _ = copy.setVisionFill(nil)
        if let held = workspaces[space], followsMaximize(of: held) {
            copy.workspaces.withSpace(space) { $0.endMaximize() }
        }
        return copy
    }
}
