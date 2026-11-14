import AppKit

/// Spread and pinch glyphs (#1873 ▸ Ruling amendment 2026-11-13,
/// owner; 2026-11-14 for the shape): arrows only, no hand and no
/// finger count. Two fingers move along the rising diagonal — never
/// the falling one, which Toggle Maximize's symbol takes — four along
/// both, and the centre stays open, unlike SF's crossed arrows.
extension CustomGlyph {
    /// Where an arrow's two ends sit, per axis from the grid's
    /// centre: `inner` at the open centre, `outer` towards the edge.
    /// An inward head stops a little further out than an outward
    /// tail, so the heads never touch.
    private static func pinchEnds(
        outward: Bool
    ) -> (inner: CGFloat, outer: CGFloat) {
        outward ? (2.5, 8) : (2.8, 8.5)
    }

    /// `n` arrows (2 or 4) pointing apart, or together when not
    /// `outward`, on the 20 × 20 grid.
    static func pinchArrows(_ n: Int, outward: Bool) {
        let axes: [(CGFloat, CGFloat)] =
            n == 2
            ? [(1, -1), (-1, 1)]  // top right, bottom left: y is down
            : [(-1, -1), (1, -1), (-1, 1), (1, 1)]
        let ends = pinchEnds(outward: outward)
        for (dx, dy) in axes {
            let inner = point(dx, dy, ends.inner)
            let outer = point(dx, dy, ends.outer)
            if outward {
                arrow(inner, outer)
            } else {
                arrow(outer, inner)
            }
        }
    }

    /// `distance` from the centre along (dx, dy), per axis.
    private static func point(
        _ dx: CGFloat,
        _ dy: CGFloat,
        _ distance: CGFloat
    ) -> NSPoint {
        NSPoint(x: 10 + dx * distance, y: 10 + dy * distance)
    }
}
