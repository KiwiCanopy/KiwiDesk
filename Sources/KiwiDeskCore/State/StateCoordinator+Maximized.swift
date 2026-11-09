import Foundation

/// Which window a Space shows maximized (#2448). The stored
/// `Space.maximized` is the toggle; this verdict is what every
/// reader takes, since the maximize ends the moment its window
/// leaves the tiled set or focus lands on another tiled member.
/// KiwiVision's derived fill answers where no toggle stands (#3064).
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
    public func handMaximizedWindow(of space: Space) -> WindowID? {
        guard let id = space.maximized?.window,
            let tiled = maximizedTiled(of: space),
            maximizeRival(of: space, window: id, tiled: tiled) == nil
        else { return nil }
        return id
    }

    /// `space`'s tiled members while its stored Maximize window is
    /// drawn tiled on a tiled layout, or nil.
    private func maximizedTiled(of space: Space) -> [WindowID]? {
        guard let id = space.maximized?.window,
            placementMode(of: space) != .floating
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
}
