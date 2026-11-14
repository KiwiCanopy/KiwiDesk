import Foundation

/// A recognized trackpad gesture (#1873): a tap or a swipe from the
/// router, or a macOS gesture event a tap with the gesture-event
/// mask hands in (#2447), named by its slot.
public struct TrackpadGestureEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case tap
        case swipe(Direction)
        /// A gesture event's input (`GestureInput.isGestureEvent`);
        /// `fingers` is unread.
        case gesture(GestureInput)
    }

    public var kind: Kind
    public var fingers: Int
    public var modifiers: ScrollChord
    /// The frame clock of the frame that decided it.
    public var time: Double
}

/// The pure decision over touch frames (#1873): taps and swipes
/// of three to five fingers, each a DISCRETE step — one swipe
/// fires once per touch, never a pan (#1656 refused a fluid one).
/// It knows nothing of bindings; the front matches those.
///
/// An episode runs from the first finger down to the last one
/// up. A swipe fires when the fingers' centre has travelled
/// `swipeDistance` along one axis since the finger count last
/// changed; a flick fires at the release — the first finger to lift
/// — as macOS takes a quick short swipe, when the centre travelled
/// `flickDistance` and still moved at `flickSpeed` over the last
/// `flickWindow`. A tap fires at the lift when no swipe fired, every
/// finger stayed within `tapTravel` and the touch lasted at most
/// `tapDuration`.
struct TrackpadGestureRouter {
    /// Normalized pad travel on either axis, so a vertical swipe
    /// fires at about two thirds of a horizontal one's travel, the
    /// pad being shorter than it is wide — chosen, as macOS's own
    /// vertical swipes are shorter too.
    static let swipeDistance: Float = 0.12
    /// The swipe's own axis must lead the other by this factor.
    static let axisDominance: Float = 1.6
    /// A flick's least travel, and the speed in pad widths per
    /// second it must still have over the window before the
    /// release. Measured 2026-11-14 on the owner's trackpad: slow
    /// swipes ended at 0.03–0.16, quick flicks at 0.67–1.24 and
    /// travelled 0.066–0.128. The travel stays above `tapTravel`, or
    /// a tap rolling one way would swipe.
    static let flickDistance: Float = 0.05
    static let flickSpeed: Float = 0.4
    static let flickWindow = 0.1
    static let tapTravel: Float = 0.04
    static let tapDuration = 0.35
    static let fingerRange = 3...5

    private struct Episode {
        var start: Double
        var maxFingers = 0
        var fired = false
        /// Where each finger first touched, for the tap's travel.
        var origins: [Int32: (Float, Float)] = [:]
        var travel: Float = 0
        /// The centre when the count last changed.
        var baseline: (Float, Float)?
        /// The centres within `flickWindow`, oldest first, since
        /// the count last changed: a landing or lifting finger
        /// jumps the centre, so a release reads the window before
        /// it.
        var recent: [(time: Double, centre: (Float, Float))] = []
        var count = 0
    }

    private var episode: Episode?

    mutating func route(_ frame: TouchFrame) -> [TrackpadGestureEvent] {
        let contacts = frame.contacts
        guard !contacts.isEmpty else { return lift(frame) }
        var current = episode ?? Episode(start: frame.time)
        current.maxFingers = max(current.maxFingers, contacts.count)
        for contact in contacts {
            guard let origin = current.origins[contact.id] else {
                current.origins[contact.id] = (contact.x, contact.y)
                continue
            }
            current.travel = max(
                current.travel,
                abs(contact.x - origin.0),
                abs(contact.y - origin.1)
            )
        }
        let centre = Self.centre(of: contacts)
        var events: [TrackpadGestureEvent] = []
        if contacts.count != current.count {
            if contacts.count < current.count {
                events += Self.release(&current, frame)
            }
            current.count = contacts.count
            current.baseline = centre
            current.recent = []
        }
        current.recent.removeAll {
            frame.time - $0.time > Self.flickWindow
        }
        current.recent.append((frame.time, centre))
        if !current.fired, Self.fingerRange.contains(contacts.count),
            let base = current.baseline,
            let direction = Self.swipe(
                from: base,
                to: centre,
                over: Self.swipeDistance
            )
        {
            current.fired = true
            events.append(
                Self.swipeEvent(direction, contacts.count, frame)
            )
        }
        episode = current
        return events
    }

    /// The flick a release decides, if the fingers that held still
    /// moved at `flickSpeed` before it.
    private static func release(
        _ episode: inout Episode,
        _ frame: TouchFrame
    ) -> [TrackpadGestureEvent] {
        guard !episode.fired, fingerRange.contains(episode.count),
            let direction = flick(of: episode)
        else { return [] }
        episode.fired = true
        return [swipeEvent(direction, episode.count, frame)]
    }

    private static func swipeEvent(
        _ direction: Direction,
        _ fingers: Int,
        _ frame: TouchFrame
    ) -> TrackpadGestureEvent {
        TrackpadGestureEvent(
            kind: .swipe(direction),
            fingers: fingers,
            modifiers: frame.modifiers,
            time: frame.time
        )
    }

    private mutating func lift(_ frame: TouchFrame) -> [TrackpadGestureEvent] {
        guard var ended = episode else { return [] }
        episode = nil
        let flicked = Self.release(&ended, frame)
        guard flicked.isEmpty else { return flicked }
        guard !ended.fired,
            Self.fingerRange.contains(ended.maxFingers),
            ended.travel <= Self.tapTravel,
            frame.time - ended.start <= Self.tapDuration
        else { return [] }
        return [
            TrackpadGestureEvent(
                kind: .tap,
                fingers: ended.maxFingers,
                modifiers: frame.modifiers,
                time: frame.time
            )
        ]
    }

    private static func centre(
        of contacts: [TouchContact]
    ) -> (Float, Float) {
        let n = Float(contacts.count)
        return (
            contacts.reduce(0) { $0 + $1.x } / n,
            contacts.reduce(0) { $0 + $1.y } / n
        )
    }

    /// The flick an episode's last window decides: `flickDistance`
    /// since the count changed, still moving that way at
    /// `flickSpeed`.
    private static func flick(of episode: Episode) -> Direction? {
        guard let base = episode.baseline,
            let first = episode.recent.first,
            let last = episode.recent.last,
            last.time > first.time,
            let direction = swipe(
                from: base,
                to: last.centre,
                over: flickDistance
            )
        else { return nil }
        let moved: Float
        switch direction {
        case .left: moved = first.centre.0 - last.centre.0
        case .right: moved = last.centre.0 - first.centre.0
        case .down: moved = first.centre.1 - last.centre.1
        case .up: moved = last.centre.1 - first.centre.1
        }
        let speed = moved / Float(last.time - first.time)
        return speed >= flickSpeed ? direction : nil
    }

    /// The direction once `distance` of travel decides one; y grows
    /// up.
    private static func swipe(
        from base: (Float, Float),
        to centre: (Float, Float),
        over distance: Float
    ) -> Direction? {
        let dx = centre.0 - base.0
        let dy = centre.1 - base.1
        if abs(dx) >= distance, abs(dx) >= abs(dy) * axisDominance {
            return dx < 0 ? .left : .right
        }
        if abs(dy) >= distance, abs(dy) >= abs(dx) * axisDominance {
            return dy < 0 ? .down : .up
        }
        return nil
    }
}
