import AppKit

/// One ⌃⌥ + scroll gesture in progress (#1656): the Space it acts
/// on, fixed when it begins, and its meters. Held by the handler
/// `wireScrollPan` installs, never by the core.
@MainActor
final class ScrollPanSession {
    /// The Space shown on the screen under a point (AX space).
    /// Live by default; a suite states its own.
    var spaceAt: @MainActor (CGPoint, StateCoordinator) -> SpaceID? = {
        point,
        state in
        let cocoa = GeometryUtils.axPoint(point)
        guard
            let screen = NSScreen.screens.first(where: {
                GeometryUtils.visibleFrame(of: $0).contains(cocoa)
            }),
            let display = screen.kiwiDisplay?.id
        else { return nil }
        return state.workspaces.activeSpace(on: display)
    }

    fileprivate var space: SpaceID?
    fileprivate var meter = ScrollStepMeter(longSwipes: false, distance: 1)

    init() {}
}

/// ⌃⌥ + scroll (#1656): on a Scrolling or Monocle Space under the
/// pointer, focus moves window to window — one per swipe or notch
/// by default (`ScrollStepMeter`) — so a row pans with the ordinary
/// focus animation and its border; elsewhere it does nothing.
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
        for _ in 0..<abs(steps) {
            guard let space = state.workspaces[id] else { return }
            if space.mode == .scrolling {
                stepScrollPan(by: steps > 0 ? -1 : 1, space: id)
            } else {
                stepMonocle(space, by: steps > 0 ? -1 : 1)
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
            let space = state.workspaces[id],
            space.mode == .scrolling || space.mode == .monocle
        else { return }
        if id != state.workspaces.activeSpace {
            applyFocusedSpaceSwitch(to: id)
        }
        session.space = id
    }

    /// One window along the row, through the arrow keys' own step
    /// (wrap, deferred raise and all), without warping the pointer.
    private func stepScrollPan(by step: Int, space id: SpaceID) {
        guard let space = state.workspaces[id],
            let focused = state.focusAnchor(of: space)
        else { return }
        let horizontal =
            tiler.settings.resolvedScrolling(for: id)
            .orientation == .horizontal
        _ = scrollingStep(
            Self.direction(step, horizontal: horizontal),
            space: space,
            focused: focused,
            swapping: false,
            warp: false
        )
    }

    private func stepMonocle(_ space: Space, by step: Int) {
        guard let focused = state.focusAnchor(of: space) else {
            return
        }
        let horizontal =
            tiler.settings.resolvedMonocle(for: space.id)
            .orientation == .horizontal
        _ = monocleCycle(
            Self.direction(step, horizontal: horizontal),
            space: space,
            focused: focused,
            swapping: false
        )
    }

    static func direction(_ step: Int, horizontal: Bool) -> Direction {
        horizontal
            ? (step > 0 ? .right : .left)
            : (step > 0 ? .down : .up)
    }
}
