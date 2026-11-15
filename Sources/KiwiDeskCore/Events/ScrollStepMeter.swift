import CoreGraphics

/// How many steps a scroll makes (#1656, #1519, rulings
/// 2026-09-29): a trackpad swipe one, as soon as its travel passes
/// the latch's threshold — and with `longSwipes`, one more every
/// `distance` of further travel, each on the axis that travel
/// leads, so right, right, down is one movement (#1873 ▸ Ruling
/// 2026-11-15); a mouse wheel one per notch,
/// except that a notch closer than `wheelQuiet` to the previous one
/// in the same direction steps nothing, so notches clicked one at
/// a time each step while a fast roll or a free spin steps once.
/// The glide after a lift never counts. Pure.
public struct ScrollStepMeter: Sendable {
    /// The notch quiet that re-arms a wheel, in seconds; a
    /// provisional number until a device logs notch intervals.
    /// Held below `ScrollGestureRouter.wheelPause`, which ends the
    /// burst and so clears the last notch.
    static let wheelQuiet = 0.12

    private let longSwipes: Bool
    private let distance: Double
    private var latch = ScrollStepLatch()
    private var fired = false
    /// Travel since the last step, both axes.
    private var travel = CGVector.zero
    /// The axis the last step took.
    private var horizontal: Bool?
    private var lastNotch: (time: Double, sign: Int)?

    /// The axis a trackpad gesture's last step took — the latch's
    /// for the first; nil before it and for a wheel. The one
    /// reading of a swipe's axis (input-and-animation.md).
    public var firedHorizontal: Bool? { horizontal }

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
            return notch(along, at: event.time)
        }
        guard !event.momentum else { return 0 }
        guard event.kind == .changed else {
            _ = latch.feed(event)
            fired = false
            travel = .zero
            horizontal = nil
            lastNotch = nil
            return 0
        }
        guard fired else {
            guard let first = latch.feed(event) else { return 0 }
            fired = true
            horizontal = latch.firedHorizontal
            return first
        }
        guard longSwipes else { return 0 }
        travel.dx += event.delta.dx
        travel.dy += event.delta.dy
        let leads = abs(travel.dx) > abs(travel.dy)
        let length = leads ? travel.dx : travel.dy
        let steps = Int(length / distance)
        guard steps != 0 else { return 0 }
        // The step's axis keeps its remainder; the other starts over.
        horizontal = leads
        let rest = length - Double(steps) * distance
        travel = leads ? CGVector(dx: rest, dy: 0) : CGVector(dx: 0, dy: rest)
        return steps
    }

    private mutating func notch(_ along: Double, at time: Double) -> Int {
        guard along != 0 else { return 0 }
        let sign = along > 0 ? 1 : -1
        defer { lastNotch = (time, sign) }
        if let last = lastNotch, last.sign == sign,
            time - last.time < Self.wheelQuiet
        {
            return 0
        }
        return sign
    }
}
