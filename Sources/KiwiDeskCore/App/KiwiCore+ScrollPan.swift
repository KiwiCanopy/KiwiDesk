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
///
/// A row goes through `navigate` but not `execute`: the gesture
/// acts on the Space under the POINTER, which the focused-command
/// preflight (#292) would refuse on every first step onto another
/// screen, since the frontmost app is still the old screen's. The
/// flip's owed focus is the one part of that preamble it keeps.
extension KiwiCore {
    /// Wires the consumer; once, at bootstrap.
    func wireScrollPan() {
        let session = ScrollPanSession()
        mouse.scroll.setHandler(.pan) { [weak self] event in
            self?.withUserMotion {
                self?.handleScrollPan(event, session: session)
            }
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
            // A Space no longer active is no longer the gesture's;
            // a step that lands on nothing has said so already.
            guard id == state.workspaces.activeSpace,
                let space = state.workspaces[id],
                stepScrollPan(space, by: step)
            else { return }
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

    /// One window on `space`; false where it landed on nothing.
    /// A row goes through the arrow keys' own `navigate` — row
    /// step, wrap, float tier (#488), dead-end bump (#436) and
    /// deferred raise alike — without warping the pointer.
    private func stepScrollPan(_ space: Space, by step: Int) -> Bool {
        let direction = Self.direction(
            step,
            horizontal: rowIsHorizontal(space)
        )
        switch space.mode {
        case .scrolling, .monocle:
            // A flip's owed focus lands first, as `execute` does
            // ahead of every focused-window command (#1391).
            runPendingMonocleFocus()
            return navigate(
                [.string(direction.rawValue)],
                swapping: false,
                warp: false
            ).isSuccess
        default:
            return stepInOrder(space, toward: direction, by: step)
        }
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

    /// Any other layout: the next or previous window in the
    /// Space's own order, floats included, wrapping at the ends. A
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
        guard ring.count > 1, let index = ring.firstIndex(of: focused)
        else {
            flashDeadEnd(focused, direction: direction)
            return false
        }
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
