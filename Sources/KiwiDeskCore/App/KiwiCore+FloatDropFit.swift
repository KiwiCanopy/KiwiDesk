import CoreGraphics

/// A float dropped past the bottom of the region it may occupy
/// keeps its top edge where it was dropped and is shrunk from the
/// bottom to fit (#1427, owner ruling 2026-10-06): moving it back
/// up would undo the user's own move, and a clipped strip below
/// the border is not a place anyone chose. The border is
/// `floatBounds`, so a bar on the lower edge counts. A drop
/// only — a retile never shrinks a parked float (#1091).
extension KiwiCore {
    /// `frame` with its bottom trimmed to `region`, floored at
    /// `floor`; past the floor the rest stays clipped, the window
    /// never moved. A frame whose top is already past the border
    /// is left alone: nothing of it is in reach to fit. AX
    /// coordinates (y grows down).
    nonisolated static func bottomFit(
        _ frame: CGRect,
        region: CGRect,
        floor: CGFloat
    ) -> CGRect {
        guard frame.maxY > region.maxY + AppBarGeometry.clampTolerance,
            frame.minY < region.maxY
        else { return frame }
        var result = frame
        result.size.height = max(
            region.maxY - frame.minY,
            min(floor, frame.height)
        )
        return result
    }

    /// The drop's bottom fit for `id`, in the region of the Space
    /// it now belongs to.
    func floatDropFit(_ id: WindowID, frame: CGRect) -> CGRect {
        guard let region = floatBounds(of: id) else { return frame }
        return Self.bottomFit(
            frame,
            region: region,
            floor: CGFloat(effectiveMinSize(of: id, axis: "y"))
        )
    }
}
