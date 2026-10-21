import Foundation

/// Which window a Space shows maximized (#2448). The stored
/// `Space.maximized` is the toggle; this verdict is what every
/// reader takes, since the maximize ends the moment its window
/// leaves the tiled set or focus lands on another tiled member.
extension StateCoordinator {
    /// The window `space` shows filling its screen, or nil: the
    /// stored `Space.maximized` while that window is a tiled
    /// member of a tiled layout and the Space's focus is on it,
    /// or on a window outside the tiled set (a float).
    public func maximizedWindow(of space: Space) -> WindowID? {
        guard let id = space.maximized, space.mode != .floating
        else { return nil }
        let tiled = localTiledMembers(of: space)
        guard tiled.contains(id) else { return nil }
        if let focus = space.focused, focus != id,
            tiled.contains(focus)
        {
            return nil
        }
        return id
    }

    /// Clears every stored maximize the verdict no longer honours,
    /// so focus coming back never re-maximizes. Returns the Spaces
    /// it cleared.
    @discardableResult
    mutating func retireEndedMaximize() -> [SpaceID] {
        let ended = workspaces.allSpaces.filter {
            $0.maximized != nil && maximizedWindow(of: $0) == nil
        }.map(\.id)
        for id in ended {
            workspaces.withSpace(id) { $0.maximized = nil }
        }
        return ended
    }
}
