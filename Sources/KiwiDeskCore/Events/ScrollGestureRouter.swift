import CoreGraphics

/// What a scroll-gesture consumer hears (#1656, #1519).
public struct ScrollGestureEvent: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case began, changed, ended
    }

    /// A trackpad gesture carries phases and momentum; a wheel
    /// burst is a run of phaseless events ended by a pause.
    public enum Input: Equatable, Sendable {
        case trackpad, wheel
    }

    public var chord: ScrollChord
    public var kind: Kind
    public var input: Input
    /// Points; zero on `.began` and `.ended`. The direction is
    /// final: `ScrollGestures.naturalScrolling` is applied before a
    /// consumer hears it.
    public var delta: CGVector
    /// True for the momentum that follows a trackpad lift.
    public var momentum: Bool
    public var location: CGPoint
}

/// Decides, per scroll event, whether a registered chord owns it
/// — and so the tap CONSUMES it — and what its consumer hears.
///
/// A gesture's owner is fixed when it STARTS: a scroll that began
/// without the chord is never taken mid-flight, and a trackpad
/// gesture that began with it keeps its momentum after the keys
/// are let go. A wheel burst ends at a pause or as soon as the
/// chord stops matching, since a wheel has no lift to wait for.
/// Pure and clock-driven: the tap calls `expire(now:)` at
/// `deadline`. Runs on the tap thread alone.
struct ScrollGestureRouter {
    /// A lift is followed by momentum within a frame or two; with
    /// none by then the gesture has ended.
    static let momentumGrace = 0.1
    /// A wheel's notches of one burst arrive well inside this.
    static let wheelPause = 0.25

    private struct Owner {
        var chord: ScrollChord
        var input: ScrollGestureEvent.Input
        var began: Bool
        /// Where the gesture last was: an expiry ends it there.
        var location: CGPoint
    }

    var chords: Set<ScrollChord> = []
    private var owner: Owner?
    /// A touch passed through without moving (`.mayBegin`): the
    /// `.began` that follows stays the app's even if the chord is
    /// pressed since. Lives for that one handoff only.
    private var passing = false
    private(set) var deadline: Double?

    /// Routes one sample: `consume` says whether the event is
    /// swallowed, `events` what the owning consumer hears. A
    /// gesture whose chord was unbound mid-flight is released, so
    /// the rest of that scroll reaches the window again.
    mutating func route(
        _ sample: ScrollSample,
        now: Double
    ) -> (consume: Bool, events: [ScrollGestureEvent]) {
        var released: [ScrollGestureEvent] = []
        if let owner, !chords.contains(owner.chord) {
            released = end(at: sample.location)
        }
        let routed = routeSample(sample, now: now)
        return (routed.consume, released + routed.events)
    }

    private mutating func routeSample(
        _ sample: ScrollSample,
        now: Double
    ) -> (consume: Bool, events: [ScrollGestureEvent]) {
        defer { owner?.location = sample.location }
        if sample.momentum != .none {
            return routeMomentum(sample, now: now)
        }
        switch sample.phase {
        case .mayBegin, .began:
            if sample.phase == .began, passing, owner == nil {
                passing = false
                return (false, [])
            }
            passing = false
            var events = end(at: sample.location)
            guard chords.contains(sample.chord) else {
                passing = sample.phase == .mayBegin
                return (false, events)
            }
            owner = Owner(
                chord: sample.chord,
                input: .trackpad,
                began: false,
                location: sample.location
            )
            deadline = nil
            if sample.phase == .began {
                events += begin(sample)
                if sample.delta != .zero {
                    events.append(event(.changed, sample))
                }
            }
            return (true, events)
        case .changed:
            guard owner?.input == .trackpad else { return (false, []) }
            let events = begin(sample) + [event(.changed, sample)]
            return (true, events)
        case .ended:
            guard owner?.input == .trackpad else {
                passing = false
                return (false, [])
            }
            deadline = now + Self.momentumGrace
            return (true, [])
        case .cancelled:
            guard owner?.input == .trackpad else {
                passing = false
                return (false, [])
            }
            return (true, end(at: sample.location))
        case .none:
            return routeWheel(sample, now: now)
        }
    }

    /// Ends an owned gesture whose deadline has passed, where it
    /// last was.
    mutating func expire(now: Double) -> [ScrollGestureEvent] {
        guard let deadline, now >= deadline, let owner else {
            return []
        }
        return end(at: owner.location)
    }

    private mutating func routeMomentum(
        _ sample: ScrollSample,
        now: Double
    ) -> (consume: Bool, events: [ScrollGestureEvent]) {
        guard owner?.input == .trackpad else { return (false, []) }
        deadline = nil
        if sample.momentum == .ended {
            return (true, end(at: sample.location))
        }
        return (true, [event(.changed, sample, momentum: true)])
    }

    private mutating func routeWheel(
        _ sample: ScrollSample,
        now: Double
    ) -> (consume: Bool, events: [ScrollGestureEvent]) {
        var events: [ScrollGestureEvent] = []
        if let owner, owner.input != .wheel || owner.chord != sample.chord {
            events = end(at: sample.location)
        }
        if owner == nil {
            guard chords.contains(sample.chord) else {
                return (false, events)
            }
            owner = Owner(
                chord: sample.chord,
                input: .wheel,
                began: false,
                location: sample.location
            )
            events += begin(sample)
        }
        deadline = now + Self.wheelPause
        return (true, events + [event(.changed, sample)])
    }

    private mutating func begin(
        _ sample: ScrollSample
    ) -> [ScrollGestureEvent] {
        guard var current = owner, !current.began else { return [] }
        current.began = true
        owner = current
        var began = event(.began, sample)
        began.delta = .zero
        return [began]
    }

    private mutating func end(
        at location: CGPoint
    ) -> [ScrollGestureEvent] {
        guard let current = owner else { return [] }
        owner = nil
        deadline = nil
        guard current.began else { return [] }
        return [
            ScrollGestureEvent(
                chord: current.chord,
                kind: .ended,
                input: current.input,
                delta: .zero,
                momentum: false,
                location: location
            )
        ]
    }

    private func event(
        _ kind: ScrollGestureEvent.Kind,
        _ sample: ScrollSample,
        momentum: Bool = false
    ) -> ScrollGestureEvent {
        ScrollGestureEvent(
            chord: owner?.chord ?? sample.chord,
            kind: kind,
            input: owner?.input ?? .wheel,
            delta: sample.delta,
            momentum: momentum,
            location: sample.location
        )
    }
}
