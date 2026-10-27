import Foundation

/// Which window a Space shows maximized (#2448). The stored
/// `Space.maximized` is the toggle; this verdict is what every
/// reader takes, since the maximize ends the moment its window
/// leaves the tiled set or focus lands on another tiled member.
extension StateCoordinator {
    /// The window `space` shows filling its screen, or nil: the
    /// stored `Space.maximized` while that window is a tiled,
    /// non-sticky member of a tiled layout and the Space's focus
    /// anchor — a tiled traveler included — is on it, or on a
    /// window the layout draws no slot for (a float).
    public func maximizedWindow(of space: Space) -> WindowID? {
        guard let id = space.maximized, space.mode != .floating,
            windows[id]?.isSticky == false,
            localTiledMembers(of: space).contains(id)
        else { return nil }
        let tiled = effectiveTiledMembers(of: space)
        if let anchor = focusAnchor(of: space, tiled: tiled),
            anchor != id, tiled.contains(anchor)
        {
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
