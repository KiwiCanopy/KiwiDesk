import AppKit
import Foundation

/// A BSP press or drag along a scrolled chain (#2542): no ratio
/// divides the chain, so every BSP ratio door — the keyboard
/// `resize`, the mouse drag, the capped writer, the floor heal —
/// reads the chain from the layout's own plan and defers to it.
extension KiwiCore {
    /// The chain BSP lays `space` out with now and the context it
    /// was laid in; nil where every window has its slot, or where
    /// the whole Space piles, which no ratio or weight divides.
    func bspChain(
        of space: Space,
        on screen: NSScreen
    ) -> (zone: RunZone, context: LayoutContext)? {
        bspChain(
            tiler.layoutInput(state: state, space: space, screen: screen)
        )
    }

    /// The chain `input` lays out — the one reading the ratio
    /// doors share, the heal included.
    func bspChain(
        _ input: (space: Space, tiled: [WindowID], context: LayoutContext)
    ) -> (zone: RunZone, context: LayoutContext)? {
        guard
            let zone = BspLayout.zones(
                for: input.tiled,
                in: input.context
            )?.first,
            !zone.piles(in: input.context)
        else { return nil }
        return (zone, input.context)
    }

    /// Grows `window` by `delta` points as a run weight where it
    /// sits in a chain lying along `axis` — the one check the
    /// keyboard press and the mouse drag share, each handing the
    /// points it measured; nil otherwise, and the caller then
    /// takes the ratio.
    func resizeBspChain(
        _ window: WindowID,
        axis: String,
        delta: Double,
        space: Space
    ) -> CommandResponse? {
        guard let screen = TilingEngine.screen(for: space.id, in: state),
            let found = bspChain(of: space, on: screen),
            found.zone.vertical == (axis == "y"),
            let index = found.zone.members.firstIndex(of: window)
        else { return nil }
        let chain = found.zone
        let context = found.context
        // Judged on what the layout drew: a window split off
        // across the chain is what the other axis divides.
        let across = BspSplit.sides(
            of: state.effectiveTiledMembers(of: space),
            slots: tiler.calculatedFrames(state: state),
            bounds: tiler.layoutBounds(on: screen, for: space),
            horizontal: axis != "x",
            chain: chain
        )
        let otherAxisDivides =
            !across.first.isEmpty || !across.second.isEmpty
        // A line laid by floor and weight, whether it hides a
        // window or not, takes the run's own step.
        if let run = chain.run(in: context) {
            return resizeInRun(
                window,
                run: RunCover.Run(zone: chain, run: run, in: context),
                axis: axis,
                delta: delta,
                space: space,
                otherAxisDivides: otherAxisDivides
            )
        }
        // A chain that fits whole shares its line by weight alone:
        // the Stack zone writer's step (`resizeStackMember`).
        let gap =
            chain.vertical
            ? context.gaps.inner.vertical : context.gaps.inner.horizontal
        let span =
            (chain.vertical ? chain.region.height : chain.region.width)
            - gap * CGFloat(chain.members.count - 1)
        let outcome = StackLayout.weightStep(
            weights: chain.members.map {
                max(space.stackWeights[$0] ?? 1, StackLayout.weightFloor)
            },
            at: index,
            delta: delta,
            span: Double(span),
            minSizes: chain.members.map {
                plannedMinSize(of: $0, axis: axis)
            }
        )
        if delta < 0, outcome.hitOwnMinimum {
            refuseShrinkAtMinimum(window, axis: axis)
        } else if delta > 0, let blocked = outcome.blockedByOther {
            refuseGrowAtNeighborMinimum(
                window,
                anchor: chain.members[blocked],
                axis: axis
            )
        }
        state.workspaces.withSpace(space.id) {
            $0.stackWeights[window] = outcome.value
        }
        return .ok()
    }
}
