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
        display(at: point).flatMap(state.workspaces.activeSpace(on:))
    }

    /// The display whose whole screen holds a point (AX space) —
    /// the one lookup both scroll gestures take (#1519).
    static func display(at point: CGPoint) -> DisplayID? {
        let cocoa = GeometryUtils.axPoint(point)
        return NSScreen.screens.first { $0.frame.contains(cocoa) }?
            .kiwiDisplay?.id
    }

    fileprivate var space: SpaceID?
    fileprivate var meter = ScrollStepMeter(longSwipes: false, distance: 1)

    init() {}
}

/// ⌃⌥ + scroll (#1656): on the Space under the pointer, focus
/// moves window to window — one per swipe or notch by default
/// (`ScrollStepMeter`). A Scrolling row pans with the ordinary
/// focus animation, a Monocle stack flips, and every other layout
/// steps through its windows in array order, so a held chord
/// always does something (owner ruling 2026-09-29). A step that
/// lands on nothing — a row end with wrap off, a lone window —
/// bumps the ring as the arrow keys do (#436), once per event.
extension KiwiCore {
    /// Wires the consumer; once, at bootstrap.
    func wireScrollPan() {
        let session = ScrollPanSession()
        mouse.scroll.setHandler(.pan) { [weak self] event in
            self?.handleScrollPan(event, session: session)
        }
    }

    func handleScrollPan(
        _ event: ScrollGestureEvent,
        session: ScrollPanSession
    ) {
        if event.kind == .began {
            beginScrollPan(at: event.location, session: session)
        }
        let steps = session.meter.feed(event)
        if event.kind == .ended { session.space = nil }
        guard steps != 0, let id = session.space else { return }
        // Content follows the fingers: moving it back brings the
        // NEXT window in, so a step runs against the delta's sign.
        let step = steps > 0 ? -1 : 1
        for _ in 0..<abs(steps) {
            guard let space = state.workspaces[id] else { return }
            let moved: Bool
            switch space.mode {
            case .scrolling: moved = stepScrollPan(by: step, space: id)
            case .monocle: moved = stepMonocle(space, by: step)
            default: moved = stepInOrder(space, by: step)
            }
            guard moved else {
                bumpScrollPan(space: id, by: step)
                return
            }
        }
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

    /// The dead-end cue on the Space's focus, toward the step:
    /// along the row's own axis where the layout has one.
    private func bumpScrollPan(space id: SpaceID, by step: Int) {
        guard let space = state.workspaces[id],
            let focused = state.focusAnchor(of: space)
        else { return }
        let horizontal: Bool
        switch space.mode {
        case .scrolling:
            horizontal =
                tiler.settings.resolvedScrolling(for: id)
                .orientation == .horizontal
        case .monocle:
            horizontal =
                tiler.settings.resolvedMonocle(for: id)
                .orientation == .horizontal
        default: horizontal = true
        }
        flashDeadEnd(
            focused,
            direction: Self.direction(step, horizontal: horizontal)
        )
    }

    /// One window along the row, through the arrow keys' own step
    /// (wrap, deferred raise and all), without warping the pointer.
    /// False where it landed on nothing.
    private func stepScrollPan(by step: Int, space id: SpaceID) -> Bool {
        guard let space = state.workspaces[id],
            let focused = state.focusAnchor(of: space)
        else { return false }
        let horizontal =
            tiler.settings.resolvedScrolling(for: id)
            .orientation == .horizontal
        return scrollingStep(
            Self.direction(step, horizontal: horizontal),
            space: space,
            focused: focused,
            swapping: false,
            warp: false
        ) != nil
    }

    /// Lands a flip's owed focus first, as `execute` does ahead of
    /// every focused-window command (#1391): two steps inside one
    /// flip would otherwise both start from the old window.
    private func stepMonocle(_ stale: Space, by step: Int) -> Bool {
        runPendingMonocleFocus()
        guard let space = state.workspaces[stale.id],
            let focused = state.focusAnchor(of: space)
        else { return false }
        let horizontal =
            tiler.settings.resolvedMonocle(for: space.id)
            .orientation == .horizontal
        return monocleCycle(
            Self.direction(step, horizontal: horizontal),
            space: space,
            focused: focused,
            swapping: false,
            warp: false
        ) != nil
    }

    /// Any other layout: the next or previous window in the
    /// Space's own order, floats included, wrapping at the ends. A
    /// native-fullscreen member is left out: it sits on a Desktop
    /// nobody shows, so the focus gate refuses it (#1345).
    private func stepInOrder(_ space: Space, by step: Int) -> Bool {
        let ring = state.effectiveMembers(of: space).filter {
            state.windows[$0]?.isFullscreen != true
        }
        guard ring.count > 1,
            let focused = state.focusAnchor(of: space),
            let index = ring.firstIndex(of: focused)
        else { return false }
        let next = (index + step + ring.count) % ring.count
        focusWindow(ring[next], warp: false)
        return true
    }

    static func direction(_ step: Int, horizontal: Bool) -> Direction {
        horizontal
            ? (step > 0 ? .right : .left)
            : (step > 0 ? .down : .up)
    }
}
