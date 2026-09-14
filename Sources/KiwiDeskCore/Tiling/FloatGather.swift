import CoreGraphics

/// The gather a space owes its members on ENTERING floating mode
/// (#1177), as one pure decision: a member partly or fully
/// outside `region` takes the quit grid (`QuitGridLayout`) over
/// it, one fully inside stays. Visibility is the whole scope —
/// no previous-mode list — and the argument is
/// docs/design-decisions.md's. `region` is the caller's
/// `floatBounds` and `grid` its `floatGrowBounds`, both carving
/// the strips a SHOWN space paints; an unshown space's grid
/// meets its bar at the activation's clamp.
public enum FloatGather {
    /// Whether `frame` counts as outside `region` — any edge
    /// past it by more than the clamp tolerance, so a frame
    /// flush against an edge is inside.
    public static func isOutside(
        _ frame: CGRect,
        of region: CGRect
    ) -> Bool {
        !region.insetBy(
            dx: -AppBarGeometry.clampTolerance,
            dy: -AppBarGeometry.clampTolerance
        ).contains(frame)
    }

    /// A target for every member of `members` whose frame is
    /// outside `region`, in member order; nothing for the rest.
    /// The grid is laid in `grid`, which is `region` unless the
    /// caller reserves the ring: the JUDGMENT takes the
    /// correctness bound, or a float flush with a bare screen
    /// edge — where no clamp ever pushes — would count as
    /// outside. `minSize` and `targetDepth` are the quit grid's
    /// own knobs, read from the same settings.
    public static func targets(
        members: [WindowID],
        frames: [WindowID: CGRect],
        region: CGRect,
        grid: CGRect? = nil,
        minSize: CGFloat,
        targetDepth: Int
    ) -> [WindowID: CGRect] {
        let outside = members.filter { id in
            guard let frame = frames[id] else { return false }
            return isOutside(frame, of: region)
        }
        guard !outside.isEmpty else { return [:] }
        return QuitGridLayout.frames(
            for: outside,
            in: grid ?? region,
            minSize: minSize,
            targetDepth: targetDepth
        )
    }
}
