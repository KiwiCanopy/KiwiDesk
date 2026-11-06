import Foundation

/// Which window a Space shows maximized (#2448). The stored
/// `Space.maximized` is the toggle; this verdict is what every
/// reader takes, since the maximize ends the moment its window
/// leaves the tiled set or focus lands on another tiled member.
extension StateCoordinator {
    /// The window `space` shows filling its screen, or nil: the
    /// stored `Space.maximized` while that window is drawn tiled
    /// on a tiled layout, a traveler included, and the Space's
    /// focus anchor is on it, or on a window the layout draws no
    /// slot for (a float). A traveler is never `space.focused`
    /// (#431), so it asks the system focus itself, and focus on
    /// another screen keeps it (#3035).
    public func maximizedWindow(of space: Space) -> WindowID? {
        let tiled = effectiveTiledMembers(of: space)
        guard let id = space.maximized, space.mode != .floating,
            tiled.contains(id)
        else { return nil }
        let rival =
            space.windows.contains(id)
            ? focusAnchor(of: space, tiled: tiled)
            : workspaces.lastFocused
        if let rival, rival != id, tiled.contains(rival) {
            return nil
        }
        return id
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
    /// so focus coming back never re-maximizes. Returns the windows
    /// whose maximize it ended.
    @discardableResult
    mutating func retireEndedMaximize() -> [WindowID] {
        let ended = workspaces.allSpaces.filter {
            guard let id = $0.maximized else { return false }
            return maximizedWindow(of: $0) == nil
                && !awaitsMaximizedReturn(id, from: $0.id)
        }
        for space in ended {
            workspaces.withSpace(space.id) { $0.maximized = nil }
        }
        return ended.compactMap(\.maximized)
    }
}
