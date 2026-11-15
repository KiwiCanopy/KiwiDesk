import CoreGraphics

/// How many steps a scroll makes (#1656, #1519, rulings
/// 2026-09-29): a trackpad swipe one, as soon as its travel passes
/// the latch's threshold — and with `longSwipes`, one more every
/// `length` mm of further finger travel, each on the axis the
/// point travel leads, so right, right, down is one movement
/// (#1873 ▸ Rulings 2026-11-15, 2026-11-16); a mouse wheel one per
/// notch,
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

    /// The fallback's rate: point travel per mm of `length` where
    /// no finger reading exists (#1873 ▸ Ruling 2026-11-16), so 10 mm
    /// counts 60 pt, the old default.
    public static let pointsPerMM = 6.0

    private let longSwipes: Bool
    /// Finger travel per step, in mm.
    private let length: Double
    private var latch = ScrollStepLatch()
    private var fired = false
    /// Point travel since the last step, both axes: the axis and
    /// sign of every step, in either unit.
    private var travel = CGVector.zero
    /// The step budget since the last step, both axes: finger mm
    /// signed by each event's point delta, or the point travel.
    private var budget = CGVector.zero
    /// The finger reading last fed, set at the latch where the
    /// touch counts in mm; nil where it counts points.
    private var finger: CGVector?
    /// The axis the last step took.
    private var horizontal: Bool?
    private var lastNotch: (time: Double, sign: Int)?

    /// The axis a trackpad gesture's last step took — the latch's
    /// for the first; nil before it and for a wheel. The one
    /// reading of a swipe's axis (input-and-animation.md).
    public var firedHorizontal: Bool? { horizontal }

    public init(longSwipes: Bool, length: Double) {
        self.longSwipes = longSwipes
        self.length = max(length, 0.1)
    }

    /// Feeds one event; answers the signed number of steps it
    /// makes — positive where the delta's larger axis is positive.
    /// `reading` is the touch reader's running finger travel in mm
    /// (`TouchGestures.travel`), nil where none runs; the unit is
    /// fixed at the latch, so a touch never counts in two.
    public mutating func feed(
        _ event: ScrollGestureEvent,
        reading: CGVector? = nil
    ) -> Int {
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
            budget = .zero
            finger = nil
            horizontal = nil
            lastNotch = nil
            return 0
        }
        guard fired else {
            guard let first = latch.feed(event) else { return 0 }
            fired = true
            horizontal = latch.firedHorizontal
            finger = event.input == .trackpad ? reading : nil
            return first
        }
        guard longSwipes else { return 0 }
        travel.dx += event.delta.dx
        travel.dy += event.delta.dy
        let distance: Double
        if let last = finger {
            // A reading gone mid-touch adds nothing: no steps, never
            // a switch to points.
            guard let now = reading else { return 0 }
            finger = now
            budget.dx += Self.signed(now.dx - last.dx, by: event.delta.dx)
            budget.dy += Self.signed(now.dy - last.dy, by: event.delta.dy)
            distance = length
        } else {
            budget = travel
            distance = length * Self.pointsPerMM
        }
        let leads = abs(travel.dx) > abs(travel.dy)
        let run = leads ? budget.dx : budget.dy
        let steps = Int(run / distance)
        guard steps != 0 else { return 0 }
        // The step's axis keeps its remainder; the other starts over,
        // and the axis is decided afresh by the travel after it.
        horizontal = leads
        let rest = run - Double(steps) * distance
        budget = leads ? CGVector(dx: rest, dy: 0) : CGVector(dx: 0, dy: rest)
        travel = finger == nil ? budget : .zero
        return steps
    }

    /// A finger move's size, taking the sign of the point delta on
    /// the same axis: the point delta has had Natural scrolling's
    /// one flip, and the pad's own axes have not.
    private static func signed(_ move: Double, by delta: Double) -> Double {
        guard delta != 0 else { return 0 }
        return delta > 0 ? abs(move) : -abs(move)
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
