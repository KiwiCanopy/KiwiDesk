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

    /// The area the gesture steps, fixed at its start (#3517).
    fileprivate var placement: PlacementID?
    fileprivate var meter = ScrollSpaceStepSession.makeMeter()

    /// One per swipe or notch: no long swipes (#1519 ruling).
    fileprivate static func makeMeter() -> ScrollStepMeter {
        ScrollStepMeter(longSwipes: false, length: 1)
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
    func handleScrollSpaceStep(
        _ event: ScrollGestureEvent,
        session: ScrollSpaceStepSession
    ) {
        if event.kind == .began {
            session.placement = session.displayAt(event.location).map {
                pointerPlacement(atAX: event.location, on: $0)
            }
            session.meter = ScrollSpaceStepSession.makeMeter()
        }
        let steps = session.meter.feed(event)
        if event.kind == .ended { session.placement = nil }
        guard steps != 0, let placement = session.placement else { return }
        // Content follows the fingers: moving it back brings the
        // NEXT Space in, so a step runs against the delta's sign.
        stepSpace(
            on: placement,
            by: steps > 0 ? -1 : 1,
            warp: false,
            scrolled: true
        )
    }

    /// The neighbour of the Space `placement` shows, in that
    /// area's order — its Space Bar's, empty Spaces included
    /// where `hide_empty` leaves them off the bar, which is a
    /// display setting and never changes reach (#1519 ruling).
    /// The one step the gesture and `focus_space_previous` /
    /// `_next` (#1655) share. Past an end it wraps round that
    /// area's order unless Wrap focus is Off, never onto another
    /// area or screen (#2592, #3517); false where it stops, which
    /// bumps. `scrolled` is required: this step is the one both
    /// inputs share (#2971).
    @discardableResult
    func stepSpace(
        on placement: PlacementID,
        by step: Int,
        warp: Bool,
        scrolled: Bool
    ) -> Bool {
        let order = state.workspaces.spaces(on: placement)
        guard let shown = state.workspaces.activeSpace(on: placement),
            let index = order.firstIndex(of: shown)
        else { return false }
        var next = index + step
        if !order.indices.contains(next) {
            guard focusWrap.mode.withinScreen == .thisScreen,
                order.count > 1
            else {
                bumpAtSpaceEnd(step, on: placement)
                return false
            }
            next = (next % order.count + order.count) % order.count
        }
        switchSpace(
            to: order[next],
            warp: warp,
            step: step,
            scrolled: scrolled
        )
        return true
    }
}
