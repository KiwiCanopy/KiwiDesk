import Foundation

/// Array stepping inside a Stack zone or a Grid's last track that
/// scrolls (#2235, #2541), split out of `KiwiCore+NavigateCommand`
/// for file size.
extension KiwiCore {
    /// Steps `focus`/`swap` along a run that hides windows,
    /// in drawn order, so the step at the edge of the shown run
    /// continues into the hidden windows — which wait parked and
    /// so are no geometric neighbour. Nil (→ the
    /// geometric search, which skips hidden windows) across the
    /// zone, at its ends, and in a zone that hides nothing.
    func runStep(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        swapping: Bool,
        warp: Bool,
        skip: (WindowID) -> Bool
    ) -> CommandResponse? {
        guard
            let zone = tiler.runCovers[space.id]?.runs.first(where: {
                $0.zone.members.contains(focused)
            })?.zone,
            let index = zone.members.firstIndex(of: focused)
        else { return nil }
        let step: Int
        switch direction {
        case .up where zone.vertical, .left where !zone.vertical:
            step = -1
        case .down where zone.vertical, .right where !zone.vertical:
            step = 1
        default:
            return nil
        }
        guard
            let next = Navigation.arrayStep(
                from: index,
                step: step,
                count: zone.members.count,
                wrap: false,
                skip: { skip(zone.members[$0]) }
            )
        else { return nil }
        let target = zone.members[next]
        if swapping {
            if refuseSwapOntoTraveler(target, in: space) {
                return .ok()
            }
            commitSwap(focused, target, in: space)
        } else {
            focusWindow(target, warp: warp)
        }
        return .ok()
    }
}
