import CoreGraphics

/// One step per scroll gesture (#1519, and #1656 on a Monocle
/// Space): the gesture's travel accumulates until it passes a
/// threshold, fires once, and the latch then holds until the
/// gesture ENDS — so one fling never streams steps. Pure.
public struct ScrollStepLatch: Sendable {
    /// Travel a trackpad gesture owes before it steps, in points.
    /// A deliberate flick clears it in its first frames; a resting
    /// hand's drift does not.
    static let trackpadThreshold = 24.0
    /// A wheel steps on its first notch: a notch is already a
    /// deliberate act, and a burst latches after it.
    static let wheelThreshold = 1.0

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
            let threshold =
                event.input == .wheel
                ? Self.wheelThreshold : Self.trackpadThreshold
            guard abs(along) >= threshold else { return nil }
            fired = true
            return along > 0 ? 1 : -1
        }
    }
}
