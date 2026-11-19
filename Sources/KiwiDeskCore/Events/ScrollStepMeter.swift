import CoreGraphics

/// How many steps a scroll makes (#1656, #1519, rulings
/// 2026-09-29): a trackpad swipe one, as soon as its travel passes
/// the latch's threshold — and with `longSwipes`, one every
/// `length` mm of net finger travel, the first included, each on
/// the axis the point travel leads, so right, right, down is one
/// movement and a wobble steps nothing (#1873 ▸ Rulings 2026-11-15,
/// 2026-11-16; #3482, #3505); a mouse wheel one per notch, except
/// that a notch closer than `wheelQuiet` to the previous one in the
/// same direction steps nothing, so notches clicked one at a time
/// each step while a fast roll or a free spin steps once. The glide
/// after a lift never counts. Pure.
public struct ScrollStepMeter: Sendable {
    /// The notch quiet that re-arms a wheel, in seconds; a
    /// provisional number until a device logs notch intervals.
    /// Held below `ScrollGestureRouter.wheelPause`, which ends the
    /// burst and so clears the last notch.
    static let wheelQuiet = 0.12

    /// The fallback's rate: point travel per mm of `length` where
    /// no finger reading exists (#1873 ▸ Ruling 2026-11-16).
    public static let pointsPerMM = 6.0

    private let longSwipes: Bool
    /// Finger travel per step, in mm.
    private let length: Double
    private var fired = false
    /// Point travel since the last step, both axes: the axis of
    /// every step, in either unit.
    private var travel = CGVector.zero
    /// The step budget, both axes, the step's remainder kept: net
    /// finger mm turned the point deltas' way (`pointWay`), or the
    /// point delta.
    private var budget = CGVector.zero
    /// The finger reading last fed where the touch counts in mm,
    /// from its first reading; nil where it counts points.
    private var finger: TouchTravel.Reading?
    /// The touch's unit, fixed once `first` settles it; nil before.
    private var countsMM: Bool?
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
    /// fixed once per touch, so a touch never counts in two.
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
            countsMM = nil
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
        if let last = finger {
            // A reading gone mid-touch adds nothing: no steps, never
            // a switch to points; one from another source (a rebuilt
            // reader, another pad) re-bases without a move.
            guard let now = reading else { return 0 }
            finger = now
            if now.source == last.source {
                add(from: last, to: now, reversed: event.reversed)
            }
            let leads = abs(travel.dx) > abs(travel.dy)
            return step(along: leads, distance: length)
        }
        budget.dx += event.delta.dx
        budget.dy += event.delta.dy
        let leads = abs(travel.dx) > abs(travel.dy)
        return step(along: leads, distance: length * Self.pointsPerMM)
    }

    /// The touch's first step, and the touch's unit, fixed for the
    /// touch once settled. A long swipe whose reading's pad carries
    /// the two fingers counts mm, its first step one `length` of net
    /// finger travel with no point floor, however fast the points
    /// ran (#3482, owner 2026-11-19), a reading lost meanwhile
    /// stepping nothing. Any other touch steps at the latch's floor
    /// and counts points: no reading, no long swipes, or a reading
    /// whose pad carries no two fingers (a Magic Mouse beside a pad).
    private mutating func first(
        _ event: ScrollGestureEvent,
        reading: TouchTravel.Reading?
    ) -> Int {
        let counts = longSwipes && event.input == .trackpad
        if counts, let now = reading {
            // The origin is the touch's first reading.
            if let last = finger, now.source == last.source {
                add(from: last, to: now, reversed: event.reversed)
            }
            finger = now
        }
        if countsMM == nil, counts, reading?.touching == true {
            countsMM = true
        }
        if countsMM == true {
            guard reading != nil else { return 0 }
            let steps = step(
                along: abs(travel.dx) > abs(travel.dy),
                distance: length
            )
            fired = steps != 0
            return steps
        }
        guard let (leads, sign) = ScrollStepLatch.named(travel) else {
            return 0
        }
        countsMM = false
        fired = true
        horizontal = leads
        finger = nil
        budget = .zero
        travel = .zero
        return sign
    }

    /// Adds the finger move between two readings of one source to
    /// the budget, net and signed as the pad moved, so a move back
    /// subtracts (#3505).
    private mutating func add(
        from last: TouchTravel.Reading,
        to now: TouchTravel.Reading,
        reversed: Bool
    ) {
        let move = Self.pointWay(
            CGVector(
                dx: now.sum.dx - last.sum.dx,
                dy: now.sum.dy - last.sum.dy
            ),
            reversed: reversed
        )
        budget.dx += move.dx
        budget.dy += move.dy
    }

    /// A pad move (x right, y up) the way the point deltas run: they
    /// reach the meter in Natural scrolling's convention, the hand's
    /// own motion with y growing down (`ScrollGestureEvent.hand`,
    /// read so by `GestureMotionLatch`), reversed whole where Natural
    /// scrolling is off. So a step's sign is the direction Natural
    /// scrolling named, never a frame's point delta (#3505).
    static func pointWay(_ move: CGVector, reversed: Bool) -> CGVector {
        let way: Double = reversed ? -1 : 1
        return CGVector(dx: move.dx * way, dy: -move.dy * way)
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
