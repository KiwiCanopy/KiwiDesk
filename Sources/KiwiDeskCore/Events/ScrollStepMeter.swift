import CoreGraphics

/// How many windows a scroll moves (#1656, ruling 2026-09-29): a
/// mouse wheel one per notch; a trackpad swipe one, as soon as its
/// travel passes the latch's threshold — and with `longSwipes`,
/// one more every `distance` of further travel. The glide after a
/// lift never counts. Pure.
///
/// With `latchesWheel` (#1519, designer and owner 2026-09-29) a
/// free-spinning wheel cannot race past its target: a notch closer
/// than `wheelQuiet` to the previous one in the same direction
/// steps nothing, so notches clicked one at a time each step while
/// a fast roll or a spin steps once.
public struct ScrollStepMeter: Sendable {
    /// The quiet that re-arms a latched wheel, in seconds; a
    /// provisional number until a device logs notch intervals.
    static let wheelQuiet = 0.12

    private let longSwipes: Bool
    private let distance: Double
    private let latchesWheel: Bool
    private var latch = ScrollStepLatch()
    private var fired = false
    private var travel = 0.0
    private var lastNotch: (time: Double, sign: Int)?

    public init(
        longSwipes: Bool,
        distance: Double,
        latchesWheel: Bool = false
    ) {
        self.longSwipes = longSwipes
        self.distance = max(distance, 1)
        self.latchesWheel = latchesWheel
    }

    /// Feeds one event; answers the signed number of steps it
    /// makes — positive where the delta's larger axis is positive.
    public mutating func feed(_ event: ScrollGestureEvent) -> Int {
        let along =
            abs(event.delta.dx) > abs(event.delta.dy)
            ? event.delta.dx : event.delta.dy
        if event.kind == .changed, event.input == .wheel {
            return notch(along, at: event.time)
        }
        guard !event.momentum else { return 0 }
        guard event.kind == .changed else {
            _ = latch.feed(event)
            fired = false
            travel = 0
            lastNotch = nil
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

    private mutating func notch(_ along: Double, at time: Double) -> Int {
        guard along != 0 else { return 0 }
        let sign = along > 0 ? 1 : -1
        defer { lastNotch = (time, sign) }
        if latchesWheel, let last = lastNotch, last.sign == sign,
            time - last.time < Self.wheelQuiet
        {
            return 0
        }
        return sign
    }
}
