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

    /// Ends every Space's maximize: an arrangement switch moves
    /// what the slots hold (#2448).
    mutating func endEveryMaximize() {
        for space in workspaces.allSpaces where space.maximized != nil {
            workspaces.withSpace(space.id) { $0.maximized = nil }
        }
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
