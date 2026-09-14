import CoreGraphics

/// The gather a space owes its members on ENTERING floating
/// mode (#1177), as one pure decision. A layout that places
/// nothing inherits the previous one's frames — scrolling's
/// scrolled-out columns, monocle's parked pile — and the user
/// inherits an arrangement they cannot reach with the mouse.
///
/// Scoped by VISIBILITY, never by the previous mode: a member
/// partly or fully outside `region` is gathered, one fully
/// inside stays exactly where it is. A plain tiled→floating
/// switch then never trips it, and no mode matrix is needed.
/// Partly-outside counts (owner ruling 2026-08-31): a sliver
/// on screen is not a reachable window.
///
/// The gathered members take the quit gather's grid
/// (`QuitGridLayout`, #197) over the region, which is what
/// keeps a pile of scrolled-out columns findable rather than
/// stacked at one edge; `region` is the space's `floatBounds`,
/// so every target already clears the painted strips.
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
    /// `minSize` and `targetDepth` are the quit grid's own
    /// knobs, read from the same settings.
    public static func targets(
        members: [WindowID],
        frames: [WindowID: CGRect],
        region: CGRect,
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
            in: region,
            minSize: minSize,
            targetDepth: targetDepth
        )
    }
}
