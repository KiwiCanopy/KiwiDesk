import CoreGraphics
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
    fileprivate var meter = ScrollStepMeter(longSwipes: false, length: 1)
    fileprivate var latch = GestureMotionLatch()
    /// A split's travel before its axis is named, both axes: the
    /// motion the chosen runner is handed once it is (#1873).
    fileprivate var unnamed = CGVector.zero

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
        mouse.pointer.setButtonHandler { [weak self] event in
            self?.withUserMotion { self?.handleButtonGesture(event) }
        }
        // The pinches and rotation: their chords reach the pointer
        // tap, and its gestures come back through the touch front's
        // one match (#1873).
        mouse.trackpad.onGestureEventChords = { [weak self] chords in
            self?.mouse.pointer.configure(gestures: chords)
        }
        mouse.pointer.setGestureHandler { [weak self] event in
            self?.mouse.trackpad.receive([event])
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
            session.unnamed = .zero
        case .changed:
            if session.action == nil {
                guard let bound = route.action(for: event),
                    let action = Self.gestureAction(
                        bound,
                        naming: event,
                        &session.unnamed
                    )
                else { return }
                session.action = action
                if let began = session.pending {
                    runScroll(action, began, session)
                }
                session.pending = nil
                // The travel that named the axis is the motion's
                // start, handed whole to the runner it chose.
                var start = event
                start.delta = session.unnamed
                runScroll(action, start, session)
                return
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
                // Only focus repeats within a touch (#1873 ▸ Ruling
                // 2026-11-15): any other family steps once.
                session.meter = ScrollStepMeter(
                    longSwipes: false,
                    length: 1
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
        case .split:
            // An axis family was handed its own runner when the
            // motion named its axis; a split here runs arms alone.
            guard let hand = session.latch.feed(event),
                case .lua(let arm) = action.step(toward: hand)
            else { return }
            runGestureLua(arm.lua, "scroll")
        case .run, .grab:
            return
        }
    }

    /// The binding a scroll motion runs (#1873): a split whose axes
    /// hold a family waits until the travel names an axis, then runs
    /// that axis's family through the whole family's own runner — the
    /// pan, the Space step — and the arms through the split's; any
    /// other binding at once. `travel` gathers the motion until then.
    static func gestureAction(
        _ bound: GestureAction,
        naming event: ScrollGestureEvent,
        _ travel: inout CGVector
    ) -> GestureAction? {
        travel.dx += event.delta.dx
        travel.dy += event.delta.dy
        guard case .split(let split) = bound, !split.axes.isEmpty else {
            return bound
        }
        let horizontal = abs(travel.dx) > abs(travel.dy)
        let along = horizontal ? travel.dx : travel.dy
        guard abs(along) >= ScrollStepLatch.trackpadThreshold else {
            return nil
        }
        let axis: GestureAxis = horizontal ? .leftRight : .upDown
        return split.axes[axis].map(GestureAction.family) ?? bound
    }

    /// How many steps a family takes for `event` and which way:
    /// along the axis the meter's step took. Pure.
    static func familyStep(
        _ meter: inout ScrollStepMeter,
        _ event: ScrollGestureEvent
    ) -> (Int, GestureDirection)? {
        let steps = meter.feed(event)
        guard steps != 0 else { return nil }
        let way = Self.direction(
            of: event.delta,
            sign: steps,
            horizontal: meter.firedHorizontal
        )
        return (abs(steps), way)
    }

    /// The direction a step of `sign` runs: along the axis the
    /// meter's last step took, never a second reading of the travel
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
        switch event.kind {
        case .swipe(let swipe):
            direction = GestureDirection(rawValue: swipe.rawValue)
        case .rotation(let clockwise):
            direction = clockwise ? .clockwise : .counterClockwise
        case .tap, .gesture: break
        }
        runGestureStep(key, action, toward: direction)
    }

    /// One step of a binding with no motion of its own — a tap, a
    /// swipe, a button press — toward `direction`, nil for none.
    func runGestureStep(
        _ key: GestureKey,
        _ action: GestureAction,
        toward direction: GestureDirection?
    ) {
        switch action.step(toward: direction) {
        case .lua(let action):
            runGestureLua(action.lua, key.spelling)
        case .family(let family):
            guard let direction else { return }
            stepFamily(family, toward: direction, key: key)
        case nil:
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
        case .focus where direction.isButton:
            // A button is no motion: Back focuses the window on the
            // left, whatever a row does with the fingers.
            runGestureLua(family.lua(direction), key.spelling)
        case .focus, .walk:
            guard let space = activeSpace else { return }
            // A row slides with the fingers: its step runs against
            // the hand, which `stepScrollPan` turns back off a row.
            // The walk's way is `stepsForward`'s, the one its
            // one-shot Lua reads too.
            let forward =
                family.stepsForward(direction) ?? direction.isBackward
            let step = forward ? 1 : -1
            let horizontal = direction.isHorizontal
            _ = stepScrollPan(
                space,
                by: step,
                swipe: family == .focus ? horizontal : nil
            )
        case .space, .swap, .display, .track, .layout:
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
        // A side button names its way: Forward is the next one.
        case _ where direction.isButton:
            self == .focus || self == .swap || self == .display
                ? nil : direction == .forward
        // The list scrolls against the hand: fingers up or left
        // show the next window, as macOS's Desktop swipe does.
        case .walk, .space: direction.isBackward
        case .track, .layout: !direction.isBackward
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
        case .layout:
            return next
                ? "KiwiDesk.cycle_mode()" : "KiwiDesk.cycle_mode(\"prev\")"
        }
    }
}
