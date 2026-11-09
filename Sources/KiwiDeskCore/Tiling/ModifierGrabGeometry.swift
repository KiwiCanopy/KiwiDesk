import CoreGraphics

/// The pure frame math of a modifier grab (#2447 ruling
/// 2026-11-08), in AX space (y grows down).
///
/// A move offsets the start frame by the pointer's travel. A
/// resize takes its handle from where the grab began: the window
/// is cut in thirds on each axis, a grab in the middle third of
/// an edge moves that edge alone, and anywhere else the corner
/// nearest the grab point, the centre cell included.
enum ModifierGrabGeometry {
    /// Which edges a resize moves.
    struct Handle: Equatable, Sendable {
        /// -1 the left edge, +1 the right, 0 neither.
        var x: Int
        /// -1 the top edge, +1 the bottom, 0 neither.
        var y: Int
    }

    /// The smallest side a resize writes, in points; the app's own
    /// minimum answers below it.
    static let minimumSide: CGFloat = 40

    /// The handle a grab at `point` takes on `frame`.
    static func handle(at point: CGPoint, on frame: CGRect) -> Handle {
        let x = third(point.x, frame.minX, frame.width)
        let y = third(point.y, frame.minY, frame.height)
        switch (x, y) {
        case (0, 0):
            // The centre cell: the nearest corner by quadrant.
            return Handle(
                x: point.x < frame.midX ? -1 : 1,
                y: point.y < frame.midY ? -1 : 1
            )
        default:
            return Handle(x: x, y: y)
        }
    }

    /// -1, 0 or +1: which third of `[origin, origin + length]` the
    /// coordinate falls in, outside the span clamped to its end.
    private static func third(
        _ value: CGFloat,
        _ origin: CGFloat,
        _ length: CGFloat
    ) -> Int {
        guard length > 0 else { return 0 }
        let share = (value - origin) / length
        if share < 1.0 / 3.0 { return -1 }
        if share > 2.0 / 3.0 { return 1 }
        return 0
    }

    /// The moved frame: the start frame offset by the travel.
    static func moved(
        _ start: CGRect,
        from grab: CGPoint,
        to point: CGPoint
    ) -> CGRect {
        start.offsetBy(dx: point.x - grab.x, dy: point.y - grab.y)
    }

    /// The resized frame: each edge the handle names follows the
    /// travel, stopping where its side would fall below
    /// `minimumSide`; the opposite edge stays put.
    static func resized(
        _ start: CGRect,
        handle: Handle,
        from grab: CGPoint,
        to point: CGPoint
    ) -> CGRect {
        let (minX, maxX) = edges(
            start.minX,
            start.maxX,
            side: handle.x,
            travel: point.x - grab.x
        )
        let (minY, maxY) = edges(
            start.minY,
            start.maxY,
            side: handle.y,
            travel: point.y - grab.y
        )
        return CGRect(
            x: minX,
            y: minY,
            width: maxX - minX,
            height: maxY - minY
        )
    }

    private static func edges(
        _ low: CGFloat,
        _ high: CGFloat,
        side: Int,
        travel: CGFloat
    ) -> (CGFloat, CGFloat) {
        switch side {
        case -1: return (min(low + travel, high - minimumSide), high)
        case 1: return (low, max(high + travel, low + minimumSide))
        default: return (low, high)
        }
    }
}
