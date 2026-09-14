import CoreGraphics

/// The gather a space owes its members on ENTERING floating mode
/// (#1177), as one pure decision: where any member is partly or
/// fully outside `region`, or piled under another's frame (a
/// monocle stack), EVERY member takes the quit grid
/// (`QuitGridLayout`, the exit gather's own function and depth,
/// so a retune of the exit retunes this) laid in `grid`; where
/// all are inside, nothing moves. Visibility is the whole
/// trigger — no previous-mode list — and the argument is
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

    /// Whether `frame` is PILED: contained, within the clamp
    /// tolerance, by another member's frame — one of the two is
    /// behind the other whatever the z-order, so a full-size
    /// monocle stack is as unreachable as a parked one (owner
    /// ruling 2026-09-14). Tiles never contain each other.
    public static func isPiled(
        _ frame: CGRect,
        among others: [CGRect]
    ) -> Bool {
        others.contains {
            $0.insetBy(
                dx: -AppBarGeometry.clampTolerance,
                dy: -AppBarGeometry.clampTolerance
            ).contains(frame)
        }
    }

    /// Whether `frames` trip the gather: any frame outside
    /// `region`, or any frame piled under another's.
    public static func trips(
        _ frames: [CGRect],
        region: CGRect
    ) -> Bool {
        frames.enumerated().contains { index, frame in
            isOutside(frame, of: region)
                || isPiled(
                    frame,
                    among: frames.enumerated()
                        .filter { $0.offset != index }
                        .map(\.element)
                )
        }
    }

    /// A target for every member of `members` with a frame, in
    /// member order, where `trips` says so — the whole space
    /// takes the grid, as at the exit (owner ruling 2026-09-14,
    /// on the device: a gathered few beside untouched columns
    /// laid exactly behind each other); nothing otherwise. The
    /// grid is laid in `grid`, which is
    /// `region` unless the caller reserves the ring: the JUDGMENT
    /// takes the correctness bound, or a float flush with a bare
    /// screen edge — where no clamp ever pushes — would trip it.
    /// `minSize` and `targetDepth` are the quit grid's own knobs,
    /// read from the same settings.
    public static func targets(
        members: [WindowID],
        frames: [WindowID: CGRect],
        region: CGRect,
        grid: CGRect? = nil,
        minSize: CGFloat,
        targetDepth: Int
    ) -> [WindowID: CGRect] {
        let framed = members.filter { frames[$0] != nil }
        guard trips(framed.map { frames[$0]! }, region: region)
        else { return [:] }
        return QuitGridLayout.frames(
            for: framed,
            in: grid ?? region,
            minSize: minSize,
            targetDepth: targetDepth
        )
    }
}
