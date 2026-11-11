import CoreGraphics

/// When a split's single action fires on a scroll (#3199 ▸ Firing):
/// once per scroll motion, then again only after a quiet gap or a
/// change of direction. A trackpad motion first travels
/// `ScrollStepLatch.trackpadThreshold`; a wheel notch fires at
/// once. The glide after a lift never counts. Pure.
public struct GestureMotionLatch: Sendable {
    /// The gap that ends one motion, in seconds: the wheel's notch
    /// quiet, so one rule decides a "new" notch for both.
    static let quiet = ScrollStepMeter.wheelQuiet

    private var travel = CGVector.zero
    /// The direction the motion in progress already fired.
    private var fired: GestureDirection?
    private var lastEvent: Double?

    public init() {}

    /// Feeds one event; answers the direction that fires, if any.
    /// Directions are the fingers' or the wheel's, read from
    /// `ScrollGestureEvent.hand`, so Natural scrolling never flips
    /// an arm.
    public mutating func feed(
        _ event: ScrollGestureEvent
    ) -> GestureDirection? {
        guard event.kind == .changed else {
            travel = .zero
            fired = nil
            lastEvent = nil
            return nil
        }
        guard !event.momentum else { return nil }
        if let lastEvent, event.time - lastEvent >= Self.quiet {
            fired = nil
            travel = .zero
        }
        lastEvent = event.time
        travel.dx += event.hand.dx
        travel.dy += event.hand.dy
        let horizontal = abs(travel.dx) > abs(travel.dy)
        let along = horizontal ? travel.dx : travel.dy
        let threshold =
            event.input == .wheel ? 0 : ScrollStepLatch.trackpadThreshold
        guard along != 0, abs(along) >= threshold else { return nil }
        let direction: GestureDirection =
            horizontal
            ? (along > 0 ? .right : .left)
            : (along > 0 ? .down : .up)
        travel = .zero
        guard direction != fired else { return nil }
        fired = direction
        return direction
    }
}
