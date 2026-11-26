import AppKit
import CoreGraphics
import Foundation

/// The BSP half of the split floor heal (#934/#1430): each split
/// heals its own ratio (#3672), the owner on its first side and the
/// rest, at the least length it takes, on its second.
extension KiwiCore {
    /// Heals every split ahead of any chain (#2542), depth by depth,
    /// re-reading the layout after each so a deeper split heals in
    /// the geometry the shallower one's heal left. Only the LOCAL
    /// members' floors count (#944's traveler ruling): a visitor's
    /// floor reads as the setting.
    func healBspSplits(
        of space: Space,
        shown: Bool,
        screen: NSScreen,
        cues: inout Set<SplitFloorCue>
    ) {
        var depth = 0
        while let live = state.workspaces[space.id] {
            let input = tiler.layoutInput(
                state: state,
                space: live,
                screen: screen
            )
            let splits = BspLayout.splits(of: input.tiled, in: input.context)
            guard depth < splits.count else { return }
            let local = Set(state.localTiledMembers(of: live))
            defer { depth += 1 }
            healBspSplit(
                splits[depth],
                space: live,
                shown: shown,
                input: input,
                slots: LayoutEngine.calculate(
                    mode: input.space.mode,
                    windows: input.tiled,
                    context: input.context
                ),
                local: local,
                cues: &cues
            )
        }
    }

    private func healBspSplit(
        _ split: BspLayout.SplitOwner,
        space: Space,
        shown: Bool,
        input: (space: Space, tiled: [WindowID], context: LayoutContext),
        slots: [WindowID: CGRect],
        local: Set<WindowID>,
        cues: inout Set<SplitFloorCue>
    ) {
        let axis = split.sideBySide ? "x" : "y"
        let global = Double(minWindowSize(in: space).on(axis: axis))
        func floor(_ id: WindowID) -> Double {
            local.contains(id) ? plannedMinSize(of: id, axis: axis) : global
        }
        let low = floor(split.owner)
        let rest = BspLayout.restMinimum(
            of: split,
            windows: input.tiled,
            in: input.context,
            floor: floor
        )
        let restCarrier = rest.carrier.flatMap {
            floor($0) > global ? $0 : nil
        }
        let press = BspSplitPress(
            split: split,
            mode: input.space.mode,
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
                self.storedBspRatio(
                    of: split.owner,
                    sideBySide: split.sideBySide,
                    in: space
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

    /// The ratio `owner`'s split stores on `space`: its own, else
    /// the shared one.
    func storedBspRatio(
        of owner: WindowID,
        sideBySide: Bool,
        in space: Space
    ) -> Double {
        sessionRatios(of: space.id).bspSplits?.ratio(
            of: owner,
            sideBySide: sideBySide
        )
            ?? {
                let bsp = tiler.settings.resolvedBsp(
                    for: space,
                    session: sessionRatios(of: space.id)
                )
                return sideBySide ? bsp.splitRatioH : bsp.splitRatioV
            }()
    }
}
