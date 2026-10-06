import AppKit

/// Where the plate strip's pages sit and how it travels (#1956).
extension SpaceSlideOverlay {
    /// A page's place in the strip: across to the right, or down
    /// for a side bar — the later Space follows on.
    static func pageOrigin(_ offset: CGFloat, _ axis: SpaceSlidePlan.Axis)
        -> CGPoint
    {
        axis == .horizontal
            ? CGPoint(x: offset, y: 0) : CGPoint(x: 0, y: -offset)
    }

    static func keyPath(_ axis: SpaceSlidePlan.Axis) -> String {
        axis == .horizontal
            ? "transform.translation.x" : "transform.translation.y"
    }

    /// The strip's translation that shows the page at `offset`.
    static func translation(
        _ offset: CGFloat,
        _ axis: SpaceSlidePlan.Axis
    ) -> CGFloat {
        axis == .horizontal ? -offset : offset
    }

    static func translated(
        _ motion: SpaceSlideStrip,
        _ axis: SpaceSlidePlan.Axis
    ) -> SpaceSlideStrip {
        let sign: CGFloat = axis == .horizontal ? -1 : 1
        return SpaceSlideStrip(
            from: sign * motion.from,
            to: sign * motion.to,
            velocity: sign * motion.velocity,
            begin: motion.begin,
            response: motion.response
        )
    }

    /// `rect` (AX) in the panel's own coordinates.
    func local(_ rect: CGRect, in current: Play) -> CGRect {
        GeometryUtils.flip(rect, primaryHeight: GeometryUtils.primaryHeight)
            .offsetBy(dx: -current.screen.minX, dy: -current.screen.minY)
    }
}
