import Foundation

/// Track-mode entry seeding (#437). When a space switches INTO the
/// track layout under fill-then-spill (`focused_track`), its
/// existing windows are packed into filled tracks — what
/// window-by-window spawning would have built — instead of one
/// column each. `own_track` keeps the every-window-its-own-track
/// seed. The packing needs the display geometry the tiler holds,
/// so it is resolved here and handed to the pure
/// `WorkspaceManager.setMode`. Every `set_mode` path routes
/// through `setSpaceMode`, so no entry can forget to seed.
extension KiwiCore {
    /// Sets a space's layout mode, seeding the track partition on a
    /// real switch into track mode; a no-op seed otherwise. Reads
    /// live `tiler.settings` for the rule and capacity, so a
    /// config-apply caller must assign `tiler.settings` BEFORE its
    /// `setSpaceMode` loop (both bulk-apply callers already do).
    func setSpaceMode(_ id: SpaceID, _ mode: LayoutMode) {
        // Compute the seed BEFORE the mutating `setMode` — reading
        // `state.workspaces` inside it would overlap the exclusive
        // access. Only on a genuine entry, so dense profile / config
        // applies (mode unchanged) pay nothing.
        let entering =
            mode == .track
            && state.workspaces[id]?.mode != .track
        let seed = entering ? trackEntrySeed(for: id) : nil
        state.workspaces.setMode(id, mode, trackSeed: seed)
    }

    /// The fill-then-spill seed for a space entering track mode:
    /// its tiled windows packed into tracks of the display's
    /// capacity (#437). `nil` under `own_track`, so `setMode` uses
    /// the every-window-its-own-track default.
    private func trackEntrySeed(
        for id: SpaceID
    ) -> Set<WindowID>? {
        guard let space = state.workspaces[id],
            tiler.settings.resolvedTrack(for: id).newWindow
                == .focusedTrack
        else { return nil }
        let capacity = tiler.trackCapacity(for: space, state: state)
        let tiled = space.windows.filter {
            state.windows[$0]?.isFloating == false
        }
        return TrackLayout.fillSeed(
            tiled: tiled,
            capacity: capacity
        )
    }
}
