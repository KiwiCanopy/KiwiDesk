import CoreGraphics

/// Where a shown peek holds under the pointer (#1946, owner ruling):
/// its item, the peek, and the hull of the item's peek-facing edge
/// and the peek's bar-facing edge — the gap a pointer crosses to
/// reach a row. A neighbour's own rect stays outside, so moving
/// along the bar still swaps. AppKit screen coordinates, y up.
enum BarPeekHull {
    static func contains(
        _ point: CGPoint,
        item: CGRect,
        peek: CGRect,
        edge: AppBarEdge
    ) -> Bool {
        if item.contains(point) || peek.contains(point) { return true }
        return Self.convex(
            bridge(item: item, peek: peek, edge: edge),
            contains: point
        )
    }

    /// The four corners between the two facing edges, in order
    /// around the quadrilateral.
    static func bridge(
        item: CGRect,
        peek: CGRect,
        edge: AppBarEdge
    ) -> [CGPoint] {
        switch edge {
        case .top:
            [
                CGPoint(x: item.minX, y: item.minY),
                CGPoint(x: item.maxX, y: item.minY),
                CGPoint(x: peek.maxX, y: peek.maxY),
                CGPoint(x: peek.minX, y: peek.maxY),
            ]
        case .bottom:
            [
                CGPoint(x: item.minX, y: item.maxY),
                CGPoint(x: item.maxX, y: item.maxY),
                CGPoint(x: peek.maxX, y: peek.minY),
                CGPoint(x: peek.minX, y: peek.minY),
            ]
        case .left:
            [
                CGPoint(x: item.maxX, y: item.minY),
                CGPoint(x: item.maxX, y: item.maxY),
                CGPoint(x: peek.minX, y: peek.maxY),
                CGPoint(x: peek.minX, y: peek.minY),
            ]
        case .right:
            [
                CGPoint(x: item.minX, y: item.minY),
                CGPoint(x: item.minX, y: item.maxY),
                CGPoint(x: peek.maxX, y: peek.maxY),
                CGPoint(x: peek.maxX, y: peek.minY),
            ]
        }
    }

    /// Whether `point` lies inside or on the convex polygon
    /// `corners`, wound either way.
    static func convex(_ corners: [CGPoint], contains point: CGPoint) -> Bool {
        var sign: CGFloat = 0
        for index in corners.indices {
            let a = corners[index]
            let b = corners[(index + 1) % corners.count]
            let cross =
                (b.x - a.x) * (point.y - a.y) - (b.y - a.y) * (point.x - a.x)
            guard cross != 0 else { continue }
            if sign == 0 {
                sign = cross
            } else if (sign > 0) != (cross > 0) {
                return false
            }
        }
        return true
    }
}
