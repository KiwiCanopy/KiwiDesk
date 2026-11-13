import CoreGraphics
import Foundation

/// One event the pointer tap hands its router: the type, the
/// event's own location (global display space, y down, which is
/// AX space) and the four modifiers held.
struct PointerSample: Equatable, Sendable {
    enum Kind: Equatable, Sendable {
        case leftDown, leftDragged, leftUp, mouseMoved, flagsChanged
        /// The right button or any other: its press, drag and
        /// release (#3281).
        case buttonDown(PointerButton)
        case buttonDragged(PointerButton)
        case buttonUp(PointerButton)
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
    /// The bound clicks and side buttons (#3281); nil while off.
    var buttons: PointerButtonSettings?

    static let off = PointerTapSnapshot(grab: nil)

    init(grab: ModifierDragSettings?, buttons: PointerButtonSettings? = nil) {
        self.grab = grab
        self.buttons = buttons
    }
}

/// A modifier grab's phase, as the router decided it.
public struct ModifierGrabEvent: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case began, moved, ended }

    public var phase: Phase
    public var action: ModifierDragAction
    /// How the grab started: `.drag` swallowed its press stream.
    public var start: ModifierDragStart
    /// The keys its binding holds.
    public var chord: ScrollChord
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
        var buttons: [PointerButtonEvent] = []

        static let pass = Routed(swallow: false, grab: [])
    }

    typealias Owner = ModifierDragBinding

    var snapshot = PointerTapSnapshot.off
    /// The grab in flight: the binding it began.
    private(set) var owner: Owner?
    /// The bound buttons held down, each with the binding its press
    /// fired: their drags and releases are the binding's too.
    /// Written by `PointerTapRouter+Buttons` alone.
    var heldButtons: [PointerButton: PointerButtonEvent] = [:]

    mutating func route(
        _ sample: PointerSample,
        now: CFAbsoluteTime
    ) -> Routed {
        // A held button pressed again lost its up: its press ends
        // first, so the front's record follows this one.
        let lost = droppingLostPress(sample, now: now)
        var routed = deciding(sample, now: now)
        routed.buttons.insert(contentsOf: lost, at: 0)
        return routed
    }

    private mutating func deciding(
        _ sample: PointerSample,
        now: CFAbsoluteTime
    ) -> Routed {
        if let held = continuingButton(sample, now: now) { return held }
        switch sample.kind {
        case .buttonDown:
            // No grab owns the right or another button's stream.
            guard let settings = snapshot.buttons else { return .pass }
            return pressing(sample, settings, now: now)
        case .buttonDragged, .buttonUp: return .pass
        default: break
        }
        if let owner {
            // The front ended a grab whose consumer or action went
            // off; the stream is no longer the grab's to swallow.
            guard let settings = snapshot.grab,
                settings.grabs.contains(owner)
            else { return endingGrab(now: now) }
            return continuing(owner, sample, settings, now: now)
        }
        for consumer in PointerConsumers.Consumer.allCases {
            switch consumer {
            case .grab:
                guard let settings = snapshot.grab else { continue }
                let routed = beginning(sample, settings, now: now)
                if routed != .pass { return routed }
            case .buttons:
                guard let settings = snapshot.buttons else { continue }
                let routed = pressing(sample, settings, now: now)
                if routed != .pass { return routed }
            }
        }
        return .pass
    }

    /// Ends the grab in flight with no location of its own — a
    /// disabled tap's re-enable, or a snapshot that turned the
    /// consumer off: no event of the grab's says where it ended.
    mutating func reseed(now: CFAbsoluteTime) -> Routed {
        var routed = endingGrab(now: now)
        routed.buttons = releasingButtons(now: now)
        return routed
    }

    /// Ends the grab in flight alone, with no location of its own.
    private mutating func endingGrab(now: CFAbsoluteTime) -> Routed {
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
            let binding = settings.binding(chord: sample.chord, start: start)
        else { return .pass }
        owner = binding
        return Routed(
            // A hover grab's moves are the pointer's own; only a
            // press stream is the grab's to take.
            swallow: start == .drag,
            grab: [event(.began, binding, sample.location, now)]
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
        case (.hover, .mouseMoved) where sample.chord == owner.chord:
            return Routed(
                swallow: false,
                grab: [event(.moved, owner, at, now)]
            )
        case (.hover, .mouseMoved), (.hover, .flagsChanged),
            (.hover, .leftDown):
            guard
                sample.chord != owner.chord || sample.kind == .leftDown
            else { return .pass }
            // A key let go, or a click: the grab ends, and the
            // event is the app's unless a bound click takes it.
            self.owner = nil
            var routed: Routed = .pass
            if sample.kind == .mouseMoved {
                routed = beginning(sample, settings, now: now)
            } else if let buttons = snapshot.buttons {
                routed = pressing(sample, buttons, now: now)
            }
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
            chord: owner.chord,
            location: location,
            time: time
        )
    }
}
