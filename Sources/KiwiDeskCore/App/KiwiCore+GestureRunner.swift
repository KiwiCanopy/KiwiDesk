import Foundation

/// One scroll gesture in progress under a bound chord (#3199): the
/// binding its first move picked, held to the lift, and each
/// family's own session. Held by the handler `wireGestures`
/// installs, never by the core.
@MainActor
final class ScrollBindingSession {
    let pan = ScrollPanSession()
    let step = ScrollSpaceStepSession()
    fileprivate var action: GestureAction?
    /// The `.began` held until a move names the binding: a wheel's
    /// axis decides which of the chord's bindings it reaches.
    fileprivate var pending: ScrollGestureEvent?
    fileprivate var meter = ScrollStepMeter(longSwipes: false, distance: 1)
    fileprivate var latch = GestureMotionLatch()

    init() {}
}

/// Where a bound gesture runs (#3199): the scroll tap's gestures
/// through their family's session, the touch reader's taps and
/// swipes as one step each. Every action runs as user motion
/// (#804).
extension KiwiCore {
    /// Wires the fronts' handlers; once, at bootstrap.
    func wireGestures() {
        let session = ScrollBindingSession()
        mouse.scroll.setHandler { [weak self] event, route in
            self?.withUserMotion {
                self?.handleScrollBinding(event, route, session)
            }
        }
        mouse.trackpad.setHandler { [weak self] key, action, event in
            self?.withUserMotion {
                self?.runTouchGesture(key, action, event)
            }
        }
    }

    func handleScrollBinding(
        _ event: ScrollGestureEvent,
        _ route: ScrollRoute,
        _ session: ScrollBindingSession
    ) {
        switch event.kind {
        case .began:
            session.action = nil
            session.pending = event
        case .changed:
            if session.action == nil {
                guard let action = route.action(for: event) else { return }
                session.action = action
                if let began = session.pending {
                    runScroll(action, began, session)
                }
                session.pending = nil
            }
            if let action = session.action {
                runScroll(action, event, session)
            }
        case .ended:
            if let action = session.action {
                runScroll(action, event, session)
            }
            session.action = nil
            session.pending = nil
        }
    }

    private func runScroll(
        _ action: GestureAction,
        _ event: ScrollGestureEvent,
        _ session: ScrollBindingSession
    ) {
        switch action {
        case .family(.focus):
            handleScrollPan(event, session: session.pan, directional: true)
        case .family(.walk):
            handleScrollPan(event, session: session.pan, directional: false)
        case .family(.space):
            handleScrollSpaceStep(event, session: session.step)
        case .family(let family):
            if event.kind == .began {
                // A swipe steps once per `step_distance`, as the pan.
                let resolved = mouse.scroll.resolved
                session.meter = ScrollStepMeter(
                    longSwipes: resolved.longSwipes,
                    distance: resolved.stepDistance
                )
            }
            guard
                let (steps, direction) = Self.familyStep(
                    &session.meter,
                    event
                )
            else { return }
            let code = family.lua(direction)
            for _ in 0..<steps { runGestureLua(code, "scroll") }
        case .split(let arms):
            guard let direction = session.latch.feed(event),
                let arm = arms[direction]
            else { return }
            runGestureLua(arm.lua, "scroll")
        case .run, .grab:
            return
        }
    }

    /// How many steps a family takes for `event` and which way:
    /// the event projected onto the axis the latch fired on, so a
    /// long swipe's later steps keep its axis and its sign. Pure.
    static func familyStep(
        _ meter: inout ScrollStepMeter,
        _ event: ScrollGestureEvent
    ) -> (Int, GestureDirection)? {
        let steps = meter.feed(
            event.locked(horizontal: meter.firedHorizontal)
        )
        guard steps != 0 else { return nil }
        let way = Self.direction(
            of: event.delta,
            sign: steps,
            horizontal: meter.firedHorizontal
        )
        return (abs(steps), way)
    }

    /// The direction a step of `sign` runs: along the axis the
    /// meter's latch fired on, never a second reading of the travel
    /// (input-and-animation.md), else the delta's larger one.
    static func direction(
        of delta: CGVector,
        sign: Int,
        horizontal: Bool?
    ) -> GestureDirection {
        (horizontal ?? (abs(delta.dx) > abs(delta.dy)))
            ? (sign > 0 ? .right : .left)
            : (sign > 0 ? .down : .up)
    }

    /// A tap's or a swipe's binding, one step.
    func runTouchGesture(
        _ key: GestureKey,
        _ action: GestureAction,
        _ event: TrackpadGestureEvent
    ) {
        var direction: GestureDirection?
        if case .swipe(let swipe) = event.kind {
            direction = GestureDirection(rawValue: swipe.rawValue)
        }
        switch action {
        case .run(let lua):
            runGestureLua(lua.lua, key.spelling)
        case .split(let arms):
            guard let direction, let arm = arms[direction] else { return }
            runGestureLua(arm.lua, key.spelling)
        case .family(let family):
            guard let direction else { return }
            stepFamily(family, toward: direction, key: key)
        case .grab:
            return
        }
    }

    /// One step of `family` the way the hand went, on the active
    /// Space: the pan's own step for a focus, so a Scrolling row
    /// slides with the fingers there too (#3200 amendment).
    func stepFamily(
        _ family: GestureFamily,
        toward direction: GestureDirection,
        key: GestureKey
    ) {
        switch family {
        case .focus, .walk:
            guard let space = activeSpace else { return }
            // A row slides with the fingers: its step runs against
            // the hand, which `stepScrollPan` turns back off a row.
            let step = direction.isBackward ? 1 : -1
            let horizontal =
                direction == .left || direction == .right
                || direction == .back || direction == .forward
            _ = stepScrollPan(
                space,
                by: step,
                swipe: family == .focus ? horizontal : nil
            )
        case .space, .swap, .display, .track:
            runGestureLua(family.lua(direction), key.spelling)
        }
    }

    func runGestureLua(_ code: String, _ origin: String) {
        guard let lua = keys.lua else { return }
        if case .failure(let error) = lua.run(code) {
            onLog("gesture \(origin): \(error)")
        }
    }
}

extension GestureFamily {
    /// Whether a list family's step toward `direction` goes to the
    /// next item (the next window, track or Space); nil for a family
    /// that steps by direction. The Lua below and Settings' arm words
    /// both read it, so the two never disagree.
    public func stepsForward(_ direction: GestureDirection) -> Bool? {
        switch self {
        // The list scrolls against the hand: fingers up or left
        // show the next window, as macOS's Desktop swipe does.
        case .walk, .space: direction.isBackward
        case .track: !direction.isBackward
        case .focus, .swap, .display: nil
        }
    }

    /// The Lua one step runs `direction`'s way. Fingers moving left
    /// reach the window, screen or track on the left; a Space step
    /// follows macOS's Desktop swipe, where fingers moving left show
    /// the next one. A focus or walk family runs the pan instead;
    /// its Lua is the one-shot step a split direction pre-fills
    /// with (#3183 ▸ Ruling: directions of a family row).
    public func lua(_ direction: GestureDirection) -> String {
        let way = direction.layout.rawValue
        let next = stepsForward(direction) == true
        switch self {
        case .swap: return "KiwiDesk.swap(\"\(way)\")"
        case .display: return "KiwiDesk.focus_display(\"\(way)\")"
        case .focus: return "KiwiDesk.focus(\"\(way)\")"
        case .track:
            return "KiwiDesk.move_to_track(\"\(next ? "next" : "prev")\")"
        case .space:
            return next
                ? "KiwiDesk.focus_space_next()"
                : "KiwiDesk.focus_space_previous()"
        case .walk:
            let step = next ? "next" : "prev"
            return "KiwiDesk.focus_space_window(\"\(step)\")"
        }
    }
}
