import CoreGraphics

/// Scroll input to travel along a shelf section (#1517), pure so
/// the mapping is testable (`ShelfScrollInputTests`). Every device
/// reaches the one axis the shelf scrolls on: the wheel, tilt and
/// shift-wheel, and a trackpad in either direction.
public enum ShelfScrollInput {
    /// One event's deltas, as `NSEvent.scrollingDeltaX/Y` report
    /// them — ALREADY corrected for natural scrolling, so nothing
    /// here flips them again. `precise` is a trackpad or Magic
    /// Mouse (points); otherwise a wheel (lines per notch).
    public struct Delta: Equatable, Sendable {
        public var x: CGFloat
        public var y: CGFloat
        public var precise: Bool

        public init(x: CGFloat, y: CGFloat, precise: Bool) {
            self.x = x
            self.y = y
            self.precise = precise
        }
    }

    /// Points to move the section's offset — positive toward its
    /// end. The dominant axis wins, whichever way the shelf lies:
    /// a vertical wheel scrolls a horizontal shelf, a sideways
    /// swipe a vertical one. A wheel notch moves `itemStep`.
    public static func travel(
        _ delta: Delta,
        itemStep: CGFloat
    ) -> CGFloat {
        let dominant = abs(delta.x) >= abs(delta.y) ? delta.x : delta.y
        // Content follows the finger: a positive delta pulls the
        // run toward its start, which is a smaller offset.
        let points = delta.precise ? dominant : dominant * itemStep
        return -points
    }
}
