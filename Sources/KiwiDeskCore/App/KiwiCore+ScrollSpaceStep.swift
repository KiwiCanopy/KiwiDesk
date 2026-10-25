import AppKit

/// One ⌃⌥⌘ + scroll gesture in progress (#1519): the screen it
/// steps, fixed when it begins, and its meter. Held by the
/// handler `wireScrollSpaceStep` installs, never by the core.
@MainActor
final class ScrollSpaceStepSession {
    /// The display under a point (AX space). Live by default; a
    /// suite states its own.
    var displayAt: @MainActor (CGPoint) -> DisplayID? = {
        GeometryUtils.display(at: $0)
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
/// fast roll or a spinning wheel once (`ScrollStepMeter`). Past
/// an end it wraps as the keys do (#2592), or under Wrap focus Off
/// stops, where the shown Space's focus bumps its ring toward the
/// step as a row end does (#436), and it never moves the pointer.
extension KiwiCore {
    /// Wires the consumer; once, at bootstrap.
    func wireScrollSpaceStep() {
        let session = ScrollSpaceStepSession()
        mouse.scroll.setHandler(.step) { [weak self] event in
            self?.withUserMotion {
                self?.handleScrollSpaceStep(event, session: session)
            }
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
        stepSpace(on: display, by: steps > 0 ? -1 : 1, warp: false)
    }

    /// The neighbour of the Space `display` shows, in that
    /// screen's order — the Space Bar's, empty Spaces included
    /// where `hide_empty` leaves them off the bar, which is a
    /// display setting and never changes reach (#1519 ruling).
    /// The one step the gesture and `focus_space_previous` /
    /// `_next` (#1655) share. Past an end it wraps round that
    /// screen's order unless Wrap focus is Off, never onto another
    /// screen (#2592); false where it stops, which bumps.
    @discardableResult
    func stepSpace(
        on display: DisplayID,
        by step: Int,
        warp: Bool
    ) -> Bool {
        let order = state.workspaces.spaces(on: display)
        guard let shown = state.workspaces.activeSpace(on: display),
            let index = order.firstIndex(of: shown)
        else { return false }
        var next = index + step
        if !order.indices.contains(next) {
            guard focusWrap.mode.withinScreen == .thisScreen,
                order.count > 1
            else {
                bumpAtSpaceEnd(step, on: display)
                return false
            }
            next = (next % order.count + order.count) % order.count
        }
        switchSpace(to: order[next], warp: warp, step: step)
        return true
    }
}
