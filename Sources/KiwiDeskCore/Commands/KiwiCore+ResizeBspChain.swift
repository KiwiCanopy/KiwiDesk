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
        space: Space,
        toward side: RunZone.PushSide
    ) -> CommandResponse? {
        guard let screen = TilingEngine.screen(for: space.id, in: state),
            let found = bspChain(of: space, on: screen),
            found.zone.vertical == (axis == "y"),
            found.zone.members.contains(window)
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
        if chain.run(in: context) != nil {
            return resizeInRun(
                window,
                zone: chain,
                context: context,
                axis: axis,
                delta: delta,
                toward: side,
                space: space,
                otherAxisDivides: otherAxisDivides
            )
        }
        return resizeFittingZone(
            window,
            zone: chain,
            context: context,
            axis: axis,
            delta: delta,
            toward: side,
            space: space
        )
    }
}
