import CoreGraphics

/// One step per scroll gesture (#1519, and #1656 on a Monocle
/// Space): the gesture's travel accumulates until it passes a
/// threshold, fires once, and the latch then holds until the
/// gesture ENDS — so one fling never streams steps. Trackpad
/// travel alone: `ScrollStepMeter` counts a wheel's notches itself
/// and hands the latch only a gesture's begin and end. Pure.
public struct ScrollStepLatch: Sendable {
    /// Travel a trackpad gesture owes before it steps, in points.
    /// A deliberate flick clears it in its first frames; a resting
    /// hand's drift does not.
    static let trackpadThreshold = 24.0

    private var travel = CGVector.zero
    private var fired = false

    public init() {}

    /// Feeds one event; answers +1 or −1 on the one event that
    /// steps, nil otherwise. Both axes count, and the axis with
    /// the larger travel picks the sign (#1519 ruling).
    public mutating func feed(_ event: ScrollGestureEvent) -> Int? {
        switch event.kind {
        case .began, .ended:
            travel = .zero
            fired = false
            return nil
        case .changed:
            guard !fired else { return nil }
            travel.dx += event.delta.dx
            travel.dy += event.delta.dy
            let along =
                abs(travel.dx) > abs(travel.dy)
                ? travel.dx : travel.dy
            guard abs(along) >= Self.trackpadThreshold else {
                return nil
            }
            fired = true
            return along > 0 ? 1 : -1
        }
    }
}
