import CoreGraphics

/// How many steps a scroll makes (#1656, #1519, rulings
/// 2026-09-29): a trackpad swipe one, as soon as its travel passes
/// the latch's threshold — and with `longSwipes`, one every
/// `length` mm of finger travel, the first included, the latch
/// its floor, each on the axis the point travel leads, so right,
/// right, down is one movement (#1873 ▸ Rulings 2026-11-15,
/// 2026-11-16; #3482); a mouse wheel one per notch,
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
    private var fired = false
    /// Point travel since the last step, both axes: the axis of
    /// every step, in either unit.
    private var travel = CGVector.zero
    /// The step budget, both axes, the step's remainder kept: finger
    /// mm signed by each event's point delta, or the point delta.
    private var budget = CGVector.zero
    /// The finger reading last fed where the touch counts in mm,
    /// from its first reading; nil where it counts points.
    private var finger: TouchTravel.Reading?
    /// The axis the last step took.
    private var horizontal: Bool?
    private var lastNotch: (time: Double, sign: Int)?

    /// The axis a trackpad gesture's last step took; nil before the
    /// first and for a wheel. The one
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
    /// fixed by the first step, so a touch never counts in two.
    public mutating func feed(
        _ event: ScrollGestureEvent,
        reading: TouchTravel.Reading? = nil
    ) -> Int {
        let along =
            abs(event.delta.dx) > abs(event.delta.dy)
            ? event.delta.dx : event.delta.dy
        if event.kind == .changed, event.input == .wheel {
            return notch(along, at: event.time)
        }
        guard !event.momentum else { return 0 }
        guard event.kind == .changed else {
            fired = false
            travel = .zero
            budget = .zero
            // A long swipe's mm origin is the reading at its begin.
            finger =
                event.kind == .began && longSwipes
                    && event.input == .trackpad ? reading : nil
            horizontal = nil
            lastNotch = nil
            return 0
        }
        travel.dx += event.delta.dx
        travel.dy += event.delta.dy
        guard fired else { return first(event, reading: reading) }
        guard longSwipes else { return 0 }
        let distance: Double
        if let last = finger {
            // A reading gone mid-touch adds nothing: no steps, never
            // a switch to points; one from another source (a rebuilt
            // reader, another pad) re-bases without a move.
            guard let now = reading else { return 0 }
            finger = now
            if now.source == last.source {
                let move = CGVector(
                    dx: now.sum.dx - last.sum.dx,
                    dy: now.sum.dy - last.sum.dy
                )
                budget.dx += Self.signed(move.dx, by: event.delta.dx)
                budget.dy += Self.signed(move.dy, by: event.delta.dy)
            }
            distance = length
        } else {
            budget.dx += event.delta.dx
            budget.dy += event.delta.dy
            distance = length * Self.pointsPerMM
        }
        let leads = abs(travel.dx) > abs(travel.dy)
        return step(along: leads, distance: distance)
    }

    /// The touch's first step: at the latch's point floor, and with
    /// a finger reading on a long swipe once the finger has also
    /// moved one `length` (#3482); with no reading, or no long
    /// swipes, at the floor alone, the touch then counting points.
    private mutating func first(
        _ event: ScrollGestureEvent,
        reading: TouchTravel.Reading?
    ) -> Int {
        let counts = longSwipes && event.input == .trackpad
        if counts, let now = reading {
            // The origin is the touch's first reading.
            if let last = finger, now.source == last.source {
                budget.dx += Self.signed(
                    now.sum.dx - last.sum.dx,
                    by: event.delta.dx
                )
                budget.dy += Self.signed(
                    now.sum.dy - last.sum.dy,
                    by: event.delta.dy
                )
            }
            finger = now
        }
        guard let (leads, sign) = ScrollStepLatch.named(travel) else {
            return 0
        }
        if counts, reading != nil, finger != nil {
            let steps = step(along: leads, distance: length)
            fired = steps != 0
            return steps
        }
        fired = true
        horizontal = leads
        finger = nil
        budget = .zero
        travel = .zero
        return sign
    }

    /// The steps `budget` holds along the leading axis at
    /// `distance` apiece. The step's axis keeps its remainder; the
    /// other starts over, and the axis is decided afresh by the
    /// travel after it.
    private mutating func step(along leads: Bool, distance: Double) -> Int {
        let run = leads ? budget.dx : budget.dy
        let steps = Int(run / distance)
        guard steps != 0 else { return 0 }
        horizontal = leads
        let rest = run - Double(steps) * distance
        budget = leads ? CGVector(dx: rest, dy: 0) : CGVector(dx: 0, dy: rest)
        travel = .zero
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
