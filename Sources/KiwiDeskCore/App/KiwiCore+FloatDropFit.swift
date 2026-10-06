import CoreGraphics

/// A float dropped past the bottom of the region it may occupy
/// keeps its top edge where it was dropped and is shrunk from the
/// bottom to fit (#1427, owner ruling 2026-10-06): moving it back
/// up would undo the user's own move, and a clipped strip below
/// the border is not a place anyone chose. The border is
/// `floatBounds`, so a bar on the lower edge counts. A hand drop
/// only, through `floatFrameFittedOnDrop`: a retile net never
/// shrinks a parked float (#1091). The engine's own size ask is
/// no layout ask, so the size-bound learner is not taught (#1694).
extension KiwiCore {
    /// One axis of a fit: `extent` cut to `room`, the window's
    /// `floor` winning the contradiction — a window is left
    /// oversized rather than asked for a size it cannot have
    /// (code review, 2026-08-29). The #1091 fit and the drop fit
    /// share it.
    nonisolated static func floorWinsExtent(
        _ extent: CGFloat,
        room: CGFloat,
        floor: CGFloat
    ) -> CGFloat {
        max(room, min(floor, extent))
    }

    /// `frame` with its bottom trimmed to `limit`, floored; the
    /// window never moves. A frame whose top is already past the
    /// limit is left alone: its title bar is out of reach, so
    /// nothing of it can be fitted. AX coordinates (y grows down).
    nonisolated static func bottomFit(
        _ frame: CGRect,
        limit: CGFloat,
        floor: CGFloat
    ) -> CGRect {
        guard frame.maxY > limit + AppBarGeometry.clampTolerance,
            frame.minY < limit
        else { return frame }
        var result = frame
        result.size.height = floorWinsExtent(
            frame.height,
            room: limit - frame.minY,
            floor: floor
        )
        return result
    }

    /// The drop's frame: the bottom trimmed first, so a bar on the
    /// lower edge has nothing left to push up; then the bar clamp
    /// for the other edges; then the bottom again, for a window a
    /// top bar pushed down. Past the floor under a bottom bar the
    /// clamp still lifts the window clear, since a bar reserves its
    /// edge for every window (#242). A window covering a screen is
    /// presenting and keeps its frame (#1787).
    func floatFrameFittedOnDrop(
        _ id: WindowID,
        frame: CGRect
    ) -> CGRect {
        guard !coversAScreen(frame) else {
            return floatFrameClampedClearOfBars(id, frame: frame)
        }
        let trimmed = dropBottomFit(id, frame: frame)
        let clamped = floatFrameClampedClearOfBars(id, frame: trimmed)
        return dropBottomFit(id, frame: clamped)
    }

    /// The bottom limit is the region's, less the ring inset the
    /// bar clamp keeps where a bar is painted on that edge.
    private func dropBottomFit(_ id: WindowID, frame: CGRect) -> CGRect {
        guard let space = state.workspaces.space(of: id),
            let region = floatBounds(on: space)
        else { return frame }
        let barBelow = paintedStrips(forSpace: space)
            .contains { $0.edge == .bottom }
        return Self.bottomFit(
            frame,
            limit: region.maxY - (barBelow ? floatRingInset : 0),
            floor: CGFloat(effectiveMinSize(of: id, axis: "y"))
        )
    }
}
