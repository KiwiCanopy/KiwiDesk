import AppKit
import CoreGraphics

/// The drop zone over an EMPTY Space's placement (#3582): another
/// area of a split screen, or another screen, showing a Space with
/// no tiled window has no slot to swap with, so the zone marks the
/// slot the dragged window takes there instead.
extension KiwiCore {
    /// The slot `id` takes when dropped at the cursor, nil unless
    /// the drop files it, tiled, into an empty Space it will lead.
    /// The destination is the drop-commit's own (`dropDestination`,
    /// #492), and every stand-down is a case the drop does not land
    /// as the zone would say: a floating-mode Space, a screen on a
    /// native full-screen or system Space (#670), a sticky the move
    /// gate refuses (#445).
    func emptyPlacementDropZone(
        _ id: WindowID,
        from origin: Space
    ) -> CGRect? {
        guard
            let destID = dropDestination(),
            destID != origin.id,
            let dest = state.workspaces[destID],
            state.placementMode(of: dest) != .floating,
            state.effectiveTiledMembers(of: dest).isEmpty,
            stickyMoveBlock(id, to: destID) == nil
        else { return nil }
        if let display = state.workspaces.display(of: destID),
            !screenShowsUserSpace(on: display)
        {
            return nil
        }
        return tiler.loneSlot(of: id, in: dest, state: state)
    }
}

extension TilingEngine {
    /// The slot `id` takes as `space`'s one tiled window, laid out
    /// on that Space's screen through its own layout input — the
    /// bounds of its area on a split screen (#3517). A what-if read:
    /// the monocle hold the input records is put back.
    func loneSlot(
        of id: WindowID,
        in space: Space,
        state: StateCoordinator
    ) -> CGRect? {
        guard let screen = Self.screen(for: space.id, in: state)
        else { return nil }
        let held = monocleShownMembers
        defer { monocleShownMembers = held }
        var input = layoutInput(state: state, space: space, screen: screen)
        input.context.focused = id
        input.context.sizeBounds = sizeBounds(for: [id])
        return LayoutEngine.calculate(
            mode: input.space.mode,
            windows: [id],
            context: input.context
        )[id]
    }
}
