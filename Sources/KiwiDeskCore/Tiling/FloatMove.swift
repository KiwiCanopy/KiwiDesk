import CoreGraphics

/// The pure geometry of the float-move verbs (#3007).
enum FloatMove {
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
}
