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
            let target = runNeighbor(
                direction,
                space: space,
                focused: focused,
                wrap: false,
                skip: skip
            )
        else { return nil }
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

    /// Where a This screen wrap from `focused` lands when its
    /// geometric `target` is back in `focused`'s own run (#2618):
    /// the run's far end, hidden or not, as Scrolling's wrap reaches
    /// its row's (#168). `target` itself where the wrap leaves the
    /// run or crosses it.
    func runWrapLanding(
        _ target: WindowID,
        from focused: WindowID,
        in space: Space,
        direction: Direction,
        skip: (WindowID) -> Bool
    ) -> WindowID {
        guard
            let zone = runZone(holding: focused, in: space),
            zone.members.contains(target)
        else { return target }
        return runNeighbor(
            direction,
            space: space,
            focused: focused,
            wrap: true,
            skip: skip
        ) ?? target
    }

    /// The next member along the run holding `focused`, in drawn
    /// order, past what `skip` refuses; nil across the zone, at an
    /// end `wrap` refuses, and outside a run that hides windows.
    private func runNeighbor(
        _ direction: Direction,
        space: Space,
        focused: WindowID,
        wrap: Bool,
        skip: (WindowID) -> Bool
    ) -> WindowID? {
        guard
            let zone = runZone(holding: focused, in: space),
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
        return Navigation.arrayStep(
            from: index,
            step: step,
            count: zone.members.count,
            wrap: wrap,
            skip: { skip(zone.members[$0]) }
        ).map { zone.members[$0] }
    }

    private func runZone(
        holding focused: WindowID,
        in space: Space
    ) -> RunZone? {
        tiler.runCovers[space.id]?.runs.first(where: {
            $0.zone.members.contains(focused)
        })?.zone
    }
}
