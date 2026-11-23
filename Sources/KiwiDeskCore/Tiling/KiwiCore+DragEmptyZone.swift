import CoreGraphics

/// The drop zone over an EMPTY Space's placement (#3582): another
/// area of a split screen, or another screen, showing a Space with
/// no tiled window of its own has no slot to swap with, so the zone
/// marks the slot the dragged window takes there instead.
extension KiwiCore {
    /// The slot `id` takes when dropped at the cursor into an empty
    /// Space, read off a copy of the state with the drop's filing
    /// written in, nil where the drop files it nowhere tiled. The
    /// destination is the drop-commit's (`crossDropDestination`),
    /// and a sticky the move gate refuses snaps back (#445). A
    /// screen on a native full-screen or system Space (#670) shows
    /// no zone, since the Space it files into is not on screen.
    func emptyPlacementDropZone(
        _ id: WindowID,
        from origin: Space
    ) -> CGRect? {
        guard let destID = crossDropDestination(from: origin),
            let dest = state.workspaces[destID],
            state.localTiledMembers(of: dest).isEmpty,
            stickyMoveBlock(id, to: destID) == nil
        else { return nil }
        if let display = state.workspaces.display(of: destID),
            !screenShowsUserSpace(on: display)
        {
            return nil
        }
        // The drop-commit's filing into an empty Space, which its
        // track rule cannot place otherwise; the activation brings
        // a global sticky along, as the drop does.
        var probe = state
        probe.workspaces.add(id, to: destID)
        probe.workspaces.focus(id, in: destID)
        probe.workspaces.activate(destID)
        return tiler.calculatedFrames(state: probe, recording: false)[id]
    }

    /// After a live crossing (#504) the window is its new Space's
    /// one tiled member of its own — the emptiness the zone above
    /// asks — so its own slot is where a drop the pointer keeps on
    /// that Space lands.
    func crossedLoneSlot(
        _ id: WindowID,
        in space: Space,
        slots: [WindowID: CGRect]
    ) -> CGRect? {
        guard dragCrossing.hasCrossed(id),
            state.localTiledMembers(of: space) == [id],
            crossDropDestination(from: space) == nil
        else { return nil }
        return slots[id]
    }
}
