import AppKit

/// One ⌃⌥⌘ + scroll gesture in progress (#1519): the screen it
/// steps, fixed when it begins, and its meter. Held by the
/// handler `wireScrollSpaceStep` installs, never by the core.
@MainActor
final class ScrollSpaceStepSession {
    /// The display under a point (AX space). Live by default; a
    /// suite states its own.
    var displayAt: @MainActor (CGPoint) -> DisplayID? = {
        ScrollPanSession.display(at: $0)
    }

    fileprivate var display: DisplayID?
    fileprivate var meter = ScrollSpaceStepSession.makeMeter()

    /// One per swipe or notch: no long swipes (#1519 ruling).
    fileprivate static func makeMeter() -> ScrollStepMeter {
        ScrollStepMeter(longSwipes: false, distance: 1)
    }

    init() {}
}

/// ⌃⌥⌘ + scroll (#1519, rulings 2026-09-28/29): steps to the
/// previous or next Space in the Space order of the screen under
/// the pointer — one per trackpad swipe, one per wheel notch, a
/// fast roll or a spinning wheel once (`ScrollStepMeter`). It
/// stops at the first and last Space, where the shown Space's
/// focus bumps its ring toward the step as a row end does (#436),
/// and never moves the pointer.
extension KiwiCore {
    /// Wires the consumer; once, at bootstrap.
    func wireScrollSpaceStep() {
        let session = ScrollSpaceStepSession()
        mouse.scroll.setHandler(.step) { [weak self] event in
            self?.handleScrollSpaceStep(event, session: session)
        }
    }

    func handleScrollSpaceStep(
        _ event: ScrollGestureEvent,
        session: ScrollSpaceStepSession
    ) {
        if event.kind == .began {
            session.display = session.displayAt(event.location)
            session.meter = ScrollSpaceStepSession.makeMeter()
        }
        let steps = session.meter.feed(event)
        if event.kind == .ended { session.display = nil }
        guard steps != 0, let display = session.display else { return }
        // Content follows the fingers: moving it back brings the
        // NEXT Space in, so a step runs against the delta's sign.
        stepSpace(on: display, by: steps > 0 ? -1 : 1)
    }

    /// The neighbour of the Space `display` shows, in that
    /// screen's order — the Space Bar's.
    private func stepSpace(on display: DisplayID, by step: Int) {
        let order = state.workspaces.spaces(on: display)
        guard let shown = state.workspaces.activeSpace(on: display),
            let index = order.firstIndex(of: shown)
        else { return }
        guard order.indices.contains(index + step) else {
            // An empty Space has no ring to bump, and says nothing.
            if let space = state.workspaces[shown],
                let focused = state.focusAnchor(of: space)
            {
                flashDeadEnd(
                    focused,
                    direction: Self.direction(step, horizontal: true)
                )
            }
            return
        }
        switchSpace(to: order[index + step], warp: false)
    }
}
