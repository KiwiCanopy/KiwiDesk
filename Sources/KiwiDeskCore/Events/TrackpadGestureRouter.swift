import Foundation

/// A recognized trackpad gesture (#1873): a tap or a swipe from the
/// router, or a macOS gesture event a tap with the gesture-event
/// mask hands in (#2447), named by its slot.
public struct TrackpadGestureEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case tap
        case swipe(Direction)
        /// A `.gestureEvents` slot's gesture; `fingers` is unread.
        case gesture(TrackpadGestureSlot)
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
/// changed; a tap fires at the lift when no swipe fired, every
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
        if contacts.count != current.count {
            current.count = contacts.count
            current.baseline = centre
        }
        var events: [TrackpadGestureEvent] = []
        if !current.fired, Self.fingerRange.contains(contacts.count),
            let base = current.baseline,
            let direction = Self.swipe(from: base, to: centre)
        {
            current.fired = true
            events.append(
                TrackpadGestureEvent(
                    kind: .swipe(direction),
                    fingers: contacts.count,
                    modifiers: frame.modifiers,
                    time: frame.time
                )
            )
        }
        episode = current
        return events
    }

    private mutating func lift(_ frame: TouchFrame) -> [TrackpadGestureEvent] {
        guard let ended = episode else { return [] }
        episode = nil
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

    /// The direction once the travel decides one; y grows up.
    private static func swipe(
        from base: (Float, Float),
        to centre: (Float, Float)
    ) -> Direction? {
        let dx = centre.0 - base.0
        let dy = centre.1 - base.1
        if abs(dx) >= swipeDistance, abs(dx) >= abs(dy) * axisDominance {
            return dx < 0 ? .left : .right
        }
        if abs(dy) >= swipeDistance, abs(dy) >= abs(dx) * axisDominance {
            return dy < 0 ? .down : .up
        }
        return nil
    }
}
