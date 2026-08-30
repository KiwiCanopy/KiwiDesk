import CoreGraphics
import KiwiDeskCore

/// Sorts displays in reading order: left to right, then top to bottom (#752).
/// Y is negated because NSScreen.frame Y grows upward; display ID breaks ties.
enum DeskOrder {
    /// The sort key for a screen at `origin` identified by `id`.
    static func key(
        origin: CGPoint,
        id: DisplayID
    ) -> (CGFloat, CGFloat, UInt32) {
        (origin.x, -origin.y, id.raw)
    }

    /// Displays in reading order.
    static func reading(_ displays: [Display]) -> [Display] {
        displays.sorted {
            key(origin: $0.frame.origin, id: $0.id)
                < key(origin: $1.frame.origin, id: $1.id)
        }
    }
}
