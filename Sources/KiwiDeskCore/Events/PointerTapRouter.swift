import CoreGraphics
import Foundation

/// One event the pointer tap hands its router: the type, the
/// event's own location (global display space, y down, which is
/// AX space) and the four modifiers held.
struct PointerSample: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case leftDown, leftDragged, leftUp, mouseMoved, flagsChanged
    }

    var kind: Kind
    var location: CGPoint
    var chord: ScrollChord
}

/// What the main actor publishes for the tap thread: each live
/// consumer's settings, already sanitised. A consumer absent here
/// is off, and its events pass.
struct PointerTapSnapshot: Equatable, Sendable {
    /// The modifier grab's (#2447); nil while off.
    var grab: ModifierDragSettings?

    static let off = PointerTapSnapshot(grab: nil)
}

/// A modifier grab's phase, as the router decided it.
public struct ModifierGrabEvent: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case began, moved, ended }

    public var phase: Phase
    public var action: ModifierDragAction
    /// How the grab started: `.drag` swallowed its press stream.
    public var start: ModifierDragStart
    /// The event's own location, AX space; nil where the grab was
    /// ended for it, with no event of its own.
    public var location: CGPoint?
    /// The tap's clock (`CFAbsoluteTimeGetCurrent`) at the event.
    public var time: CFAbsoluteTime
}

/// The pointer tap's pure decision (#2447, #2764 ruling): each
/// event against the snapshot, from the event's own location and
/// flags, never a remembered position. The one state kept is
/// which consumer owns the stream it began: an owner continues
/// it to its end, and only then may a consumer begin another, in
/// `PointerConsumers.Consumer` order.
struct PointerTapRouter {
    /// What the tap does with one event.
    struct Routed: Equatable {
        var swallow: Bool
        var grab: [ModifierGrabEvent]

        static let pass = Routed(swallow: false, grab: [])
    }

    typealias Owner = (action: ModifierDragAction, start: ModifierDragStart)

    var snapshot = PointerTapSnapshot.off
    /// The grab in flight: its action and how it started.
    private(set) var owner: Owner?

    mutating func route(
        _ sample: PointerSample,
        now: CFAbsoluteTime
    ) -> Routed {
        if let owner {
            // The front ended a grab whose consumer or action went
            // off; the stream is no longer the grab's to swallow.
            guard let settings = snapshot.grab,
                !settings[owner.action].isOff
            else { return reseed(now: now) }
            return continuing(owner, sample, settings, now: now)
        }
        for consumer in PointerConsumers.Consumer.allCases {
            switch consumer {
            case .grab:
                guard let settings = snapshot.grab else { continue }
                let routed = beginning(sample, settings, now: now)
                if routed != .pass { return routed }
            }
        }
        return .pass
    }

    /// Ends the grab in flight with no location of its own — a
    /// disabled tap's re-enable, or a snapshot that turned the
    /// consumer off: no event of the grab's says where it ended.
    mutating func reseed(now: CFAbsoluteTime) -> Routed {
        guard let owner else { return .pass }
        self.owner = nil
        return Routed(
            swallow: false,
            grab: [event(.ended, owner, nil, now)]
        )
    }

    private mutating func beginning(
        _ sample: PointerSample,
        _ settings: ModifierDragSettings,
        now: CFAbsoluteTime
    ) -> Routed {
        let start: ModifierDragStart
        switch sample.kind {
        case .leftDown: start = .drag
        case .mouseMoved: start = .hover
        default: return .pass
        }
        guard
            let action = ModifierDragAction.allCases.first(where: {
                let binding = settings[$0]
                return !binding.isOff && binding.start == start
                    && binding.chord == sample.chord
            })
        else { return .pass }
        owner = (action, start)
        return Routed(
            // A hover grab's moves are the pointer's own; only a
            // press stream is the grab's to take.
            swallow: start == .drag,
            grab: [event(.began, (action, start), sample.location, now)]
        )
    }

    private mutating func continuing(
        _ owner: Owner,
        _ sample: PointerSample,
        _ settings: ModifierDragSettings,
        now: CFAbsoluteTime
    ) -> Routed {
        let at = sample.location
        switch (owner.start, sample.kind) {
        case (.drag, .leftDragged):
            return Routed(
                swallow: true,
                grab: [event(.moved, owner, at, now)]
            )
        case (.drag, .leftUp):
            self.owner = nil
            return Routed(
                swallow: true,
                grab: [event(.ended, owner, at, now)]
            )
        case (.drag, .leftDown), (.drag, .mouseMoved):
            // A press, or a move with no button, inside a press
            // stream: its up was lost. The grab ends where its
            // last drag left it, and this event starts afresh.
            return restarting(owner, sample, settings, now: now)
        case (.hover, .mouseMoved)
        where sample.chord == settings[owner.action].chord:
            return Routed(
                swallow: false,
                grab: [event(.moved, owner, at, now)]
            )
        case (.hover, .mouseMoved), (.hover, .flagsChanged),
            (.hover, .leftDown):
            guard
                sample.chord != settings[owner.action].chord
                    || sample.kind == .leftDown
            else { return .pass }
            // A key let go, or a click: the grab ends and the
            // event is the app's.
            self.owner = nil
            var routed =
                sample.kind == .mouseMoved
                ? beginning(sample, settings, now: now) : .pass
            routed.grab.insert(event(.ended, owner, at, now), at: 0)
            return routed
        default:
            return .pass
        }
    }

    private mutating func restarting(
        _ owner: Owner,
        _ sample: PointerSample,
        _ settings: ModifierDragSettings,
        now: CFAbsoluteTime
    ) -> Routed {
        self.owner = nil
        var routed = beginning(sample, settings, now: now)
        routed.grab.insert(event(.ended, owner, nil, now), at: 0)
        return routed
    }

    private func event(
        _ phase: ModifierGrabEvent.Phase,
        _ owner: Owner,
        _ location: CGPoint?,
        _ time: CFAbsoluteTime
    ) -> ModifierGrabEvent {
        ModifierGrabEvent(
            phase: phase,
            action: owner.action,
            start: owner.start,
            location: location,
            time: time
        )
    }
}
