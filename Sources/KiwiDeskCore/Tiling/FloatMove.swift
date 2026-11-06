import CoreGraphics

/// The pure geometry of the float-move verbs (#3007, #2972).
enum FloatMove {
    /// Floating-point slack, no tolerance: a glide's step is a fraction
    /// of a point, and at a wall it must still count as stopped.
    private static let stopEpsilon: CGFloat = 0.001

    /// `clamped`, whose bar push may not carry an edge past `region`'s
    /// top or left where `frame` had not gone already: a window filling
    /// the region under a bottom or right bar keeps its title bar in
    /// reach, and one parked past that edge by hand stays there.
    static func keepingNearEdges(
        _ clamped: CGRect,
        of frame: CGRect,
        in region: CGRect
    ) -> CGRect {
        var kept = clamped
        kept.origin.x = keptEdge(
            clamped.minX,
            from: frame.minX,
            low: region.minX
        )
        kept.origin.y = keptEdge(
            clamped.minY,
            from: frame.minY,
            low: region.minY
        )
        return kept
    }

    private static func keptEdge(
        _ clamped: CGFloat,
        from origin: CGFloat,
        low: CGFloat
    ) -> CGFloat {
        clamped < origin ? max(clamped, min(origin, low)) : clamped
    }

    /// `frame` moved `delta` along one axis, stopping where it would
    /// leave `bounds`. A window parked past an edge by hand travels
    /// freely coming back; going further out this answers the wall,
    /// which `holdingTheAsk` turns into staying put. A window larger
    /// than `bounds` may reach its top or left edge and no further.
    static func moved(
        _ frame: CGRect,
        horizontal: Bool,
        delta: Double,
        bounds: CGRect
    ) -> CGRect {
        let origin = horizontal ? frame.minX : frame.minY
        let extent = horizontal ? frame.width : frame.height
        let low = horizontal ? bounds.minX : bounds.minY
        let high = (horizontal ? bounds.maxX : bounds.maxY) - extent
        let wanted = origin + CGFloat(delta)
        let next =
            delta > 0
            ? min(wanted, max(high, low))
            : max(wanted, low)
        return setting(frame, horizontal: horizontal, to: next)
    }

    /// `target`, held at `base` on the moved axis where the wall or a
    /// bar's push would send it back against the ask. A clamp acts only
    /// past its tolerance, so small steps into a bar rest up to that
    /// tolerance inside the ring's clearance, which the clamp then
    /// leaves alone; one large step lands on the clearance itself.
    static func holdingTheAsk(
        _ target: CGRect,
        from base: CGRect,
        horizontal: Bool,
        delta: Double
    ) -> CGRect {
        let from = horizontal ? base.minX : base.minY
        let to = horizontal ? target.minX : target.minY
        let back = delta > 0 ? to < from : delta < 0 && to > from
        return back
            ? setting(target, horizontal: horizontal, to: from)
            : target
    }

    /// Whether `target` falls short of the full `delta` from `base`.
    static func stoppedShort(
        of base: CGRect,
        at target: CGRect,
        horizontal: Bool,
        delta: Double
    ) -> Bool {
        let from = horizontal ? base.minX : base.minY
        let to = horizontal ? target.minX : target.minY
        let asked = from + CGFloat(delta)
        return delta > 0
            ? to < asked - stopEpsilon
            : to > asked + stopEpsilon
    }

    private static func setting(
        _ frame: CGRect,
        horizontal: Bool,
        to origin: CGFloat
    ) -> CGRect {
        var moved = frame
        if horizontal {
            moved.origin.x = origin
        } else {
            moved.origin.y = origin
        }
        return moved
    }
}
