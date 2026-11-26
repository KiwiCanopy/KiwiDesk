import CoreGraphics
import Foundation

/// The BSP half of the split floor heal (#934/#1430): each split
/// heals its own ratio (#3672), the owner on its first side and the
/// rest, at the least length it takes, on its second.
extension KiwiCore {
    func healBspSplit(
        _ split: BspLayout.SplitOwner,
        space: Space,
        shown: Bool,
        input: (space: Space, tiled: [WindowID], context: LayoutContext),
        slots: [WindowID: CGRect],
        cues: inout Set<SplitFloorCue>
    ) {
        let axis = split.sideBySide ? "x" : "y"
        let global = Double(minWindowSize(in: space).on(axis: axis))
        let low = plannedMinSize(of: split.owner, axis: axis)
        let rest = BspLayout.restMinimum(
            of: split,
            windows: input.tiled,
            in: input.context
        ) { plannedMinSize(of: $0, axis: axis) }
        let restCarrier = rest.carrier.flatMap {
            plannedMinSize(of: $0, axis: axis) > global ? $0 : nil
        }
        let press = BspSplitPress(
            split: split,
            tiled: input.tiled,
            context: input.context,
            slots: slots
        )
        healSplit(
            axis: axis,
            low: [split.owner],
            high: split.rest,
            lowMin: (low, low > global ? split.owner : nil),
            highMin: (rest.size, restCarrier),
            available: split.available,
            space: space,
            shown: shown,
            span: split.available,
            context: input.context,
            cues: &cues,
            current: { space in
                self.sessionRatios(of: space.id).bspSplits?.ratio(
                    of: split.owner,
                    sideBySide: split.sideBySide
                )
                    ?? self.sharedBspRatio(
                        of: space,
                        sideBySide: split.sideBySide
                    )
            },
            write: { ratio, _ in
                self.writeCappedBspSplit(
                    press,
                    proposed: ratio,
                    axis: axis,
                    space: space,
                    focused: nil
                )
            }
        )
    }

    /// The ratio a split with none of its own takes on `space`.
    func sharedBspRatio(of space: Space, sideBySide: Bool) -> Double {
        let bsp = tiler.settings.resolvedBsp(
            for: space,
            session: sessionRatios(of: space.id)
        )
        return sideBySide ? bsp.splitRatioH : bsp.splitRatioV
    }
}
