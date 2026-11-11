import AppKit

/// One ⌃⌥ + scroll gesture in progress (#1656): the Space it acts
/// on, fixed when it begins, and its meters. Held by the handler
/// `wireScrollPan` installs, never by the core.
@MainActor
final class ScrollPanSession {
    /// The Space shown on the screen under a point (AX space) —
    /// the whole screen, menu bar and Dock strip included.
    /// Live by default; a suite states its own.
    var spaceAt: @MainActor (CGPoint, StateCoordinator) -> SpaceID? = {
        point,
        state in
        GeometryUtils.display(at: point)
            .flatMap(state.workspaces.activeSpace(on:))
    }

    fileprivate var space: SpaceID?
    fileprivate var meter = ScrollStepMeter(longSwipes: false, distance: 1)
    /// A swipe's axis, locked by its first step and held to the
    /// lift (#3200); nil before it and for a wheel.
    fileprivate var horizontal: Bool?

    init() {}
}

/// ⌃⌥ + scroll (#1656): on the Space under the pointer, focus
/// moves window to window — one per swipe or notch by default
/// (`ScrollStepMeter`). A Scrolling row pans with the ordinary
/// focus animation and a Monocle stack flips. On every other
/// layout a swipe — a scroll with a finger phase — steps focus
/// the way the fingers go, on the axis its first step locks, and
/// a wheel notch walks the windows in array order (#3200; Natural
/// scrolling off reverses both senses upstream). A step that
/// lands on nothing — a row end with wrap off, a lone window —
/// bumps the ring as the arrow keys do (#436), once per event.
///
/// A row goes through `navigate` but not `execute`: the gesture
/// acts on the Space under the POINTER, which the focused-command
/// preflight (#292) would refuse on every first step onto another
/// screen, since the frontmost app is still the old screen's. The
/// flip's owed focus is the one part of that preamble it keeps.
extension KiwiCore {
    /// `directional` is the focus family's: a swipe steps the way
    /// it goes off a row; the walk family keeps the list.
    func handleScrollPan(
        _ event: ScrollGestureEvent,
        session: ScrollPanSession,
        directional: Bool
    ) {
        if event.kind == .began {
            beginScrollPan(at: event.location, session: session)
        }
        let steps = session.meter.feed(locked(event, session))
        if event.kind == .ended { session.space = nil }
        guard steps != 0, let id = session.space else { return }
        if event.input == .trackpad, session.horizontal == nil {
            session.horizontal = session.meter.firedHorizontal
        }
        let swipe =
            directional && event.input == .trackpad ? session.horizontal : nil
        // The step a row slides by: content follows the fingers,
        // so it runs against the delta's sign. A swipe off a row
        // turns it back in `stepScrollPan`.
        let step = steps > 0 ? -1 : 1
        for _ in 0..<abs(steps) {
            // A Space no longer active is no longer the gesture's;
            // a step that lands on nothing has said so already.
            guard id == state.workspaces.activeSpace,
                let space = state.workspaces[id],
                stepScrollPan(space, by: step, swipe: swipe)
            else { return }
        }
    }

    /// A swipe's event as the meter hears it: whole until the
    /// axis locks, then along the locked axis alone, so a
    /// diagonal never changes axis before the fingers lift.
    private func locked(
        _ event: ScrollGestureEvent,
        _ session: ScrollPanSession
    ) -> ScrollGestureEvent {
        guard event.input == .trackpad, !event.momentum else {
            return event
        }
        guard event.kind == .changed else {
            session.horizontal = nil
            return event
        }
        guard let horizontal = session.horizontal else { return event }
        var along = event
        if horizontal {
            along.delta.dy = 0
        } else {
            along.delta.dx = 0
        }
        return along
    }

    /// Fixes the gesture's Space and makes it the active one, so
    /// the focus the gesture moves lands on the screen it is on.
    private func beginScrollPan(
        at location: CGPoint,
        session: ScrollPanSession
    ) {
        session.space = nil
        let resolved = mouse.scroll.resolved
        session.meter = ScrollStepMeter(
            longSwipes: resolved.longSwipes,
            distance: resolved.stepDistance
        )
        guard let id = session.spaceAt(location, state),
            state.workspaces[id] != nil
        else { return }
        if id != state.workspaces.activeSpace {
            applyFocusedSpaceSwitch(to: id)
        }
        session.space = id
    }

    /// One window on `space`; false where it landed on nothing.
    /// `swipe` is a swipe's locked axis (horizontal or not), nil
    /// for a wheel. A row, and a swipe on any layout, go through
    /// the arrow keys' own `navigate` — row step, wrap, float tier
    /// (#488), dead-end bump (#436), deferred raise and a lens's
    /// skip alike — without warping the pointer.
    func stepScrollPan(
        _ space: Space,
        by step: Int,
        swipe: Bool?
    ) -> Bool {
        let row = space.mode == .scrolling || space.mode == .monocle
        guard row || swipe != nil else {
            let direction = Self.direction(step, horizontal: true)
            return stepInOrder(space, toward: direction, by: step)
        }
        // A row slides with the fingers; any other layout's focus
        // moves with them, so its step runs with the delta (#3200).
        let direction =
            row
            ? Self.direction(step, horizontal: rowIsHorizontal(space))
            : Self.direction(-step, horizontal: swipe ?? true)
        return navigate(
            [.string(direction.rawValue)],
            swapping: false,
            warp: false,
            wrap: focusWrap.mode.withinScreen
        ).isSuccess
    }

    /// The axis a step on `space` runs along: the row's own where
    /// the layout has one.
    private func rowIsHorizontal(_ space: Space) -> Bool {
        switch space.mode {
        case .scrolling:
            tiler.settings.resolvedScrolling(for: space.id)
                .orientation == .horizontal
        case .monocle:
            tiler.settings.resolvedMonocle(for: space.id)
                .orientation == .horizontal
        default: true
        }
    }

    /// A wheel on any other layout: the next or previous window
    /// in the Space's own order, floats included, wrapping at the ends,
    /// past every window a lens leaves out (#2103 ruling 45). A
    /// native-fullscreen member is left out: it sits on a Desktop
    /// nobody shows, so the focus gate refuses it (#1345).
    private func stepInOrder(
        _ space: Space,
        toward direction: Direction,
        by step: Int
    ) -> Bool {
        let ring = state.effectiveMembers(of: space).filter {
            state.windows[$0]?.isFullscreen != true
        }
        guard let focused = state.focusAnchor(of: space) else {
            return false
        }
        let skip = lensKeySkip() ?? { _ in false }
        guard let index = ring.firstIndex(of: focused),
            let next = Navigation.arrayStep(
                from: index,
                step: step,
                count: ring.count,
                wrap: true,
                skip: { skip(ring[$0]) }
            )
        else {
            flashDeadEnd(focused, direction: direction)
            return false
        }
        focusWindow(ring[next], warp: false)
        return true
    }

    static func direction(_ step: Int, horizontal: Bool) -> Direction {
        horizontal
            ? (step > 0 ? .right : .left)
            : (step > 0 ? .down : .up)
    }
}
