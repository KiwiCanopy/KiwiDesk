import CoreGraphics

/// How many windows a scroll moves (#1656, ruling 2026-09-29): a
/// mouse wheel one per notch; a trackpad swipe one, as soon as its
/// travel passes the latch's threshold — and with `longSwipes`,
/// one more every `distance` of further travel. The glide after a
/// lift never counts. Pure.
public struct ScrollStepMeter: Sendable {
    private let longSwipes: Bool
    private let distance: Double
    private var latch = ScrollStepLatch()
    private var fired = false
    private var travel = 0.0

    public init(longSwipes: Bool, distance: Double) {
        self.longSwipes = longSwipes
        self.distance = max(distance, 1)
    }

    /// Feeds one event; answers the signed number of steps it
    /// makes — positive where the delta's larger axis is positive.
    public mutating func feed(_ event: ScrollGestureEvent) -> Int {
        let along =
            abs(event.delta.dx) > abs(event.delta.dy)
            ? event.delta.dx : event.delta.dy
        if event.kind == .changed, event.input == .wheel {
            return along == 0 ? 0 : (along > 0 ? 1 : -1)
        }
        guard !event.momentum else { return 0 }
        guard event.kind == .changed else {
            _ = latch.feed(event)
            fired = false
            travel = 0
            return 0
        }
        guard fired else {
            guard let first = latch.feed(event) else { return 0 }
            fired = true
            return first
        }
        guard longSwipes else { return 0 }
        travel += along
        let steps = Int(travel / distance)
        travel -= Double(steps) * distance
        return steps
    }
}
