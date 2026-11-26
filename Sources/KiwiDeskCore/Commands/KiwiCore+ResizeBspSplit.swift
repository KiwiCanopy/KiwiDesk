import CoreGraphics
import Foundation

/// A BSP resize moves ONE split (#3672): the one
/// `BspLayout.splitOwner` names, at the ratio that split's owner
/// stores. The keyboard press and the mouse drag both resolve it
/// here, press from the ratio the split is drawn at, and write
/// through `writeCappedBspSplit`.
extension KiwiCore {
    /// The split a resize of `window` along `axis` moves at `edge`,
    /// with the layout input and the slots it was read from; nil
    /// where `window` is not tiled here or no split bounds that edge.
    func bspSplit(
        of window: WindowID,
        axis: String,
        edge: BspLayout.SplitEdge,
        space: Space
    ) -> BspSplitPress? {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return nil }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        guard
            let split = BspLayout.splitOwner(
                of: window,
                horizontal: axis == "x",
                edge: edge,
                windows: input.tiled,
                in: input.context
            )
        else { return nil }
        let slots = LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: input.context
        )
        return BspSplitPress(
            split: split,
            mode: input.space.mode,
            tiled: input.tiled,
            context: input.context,
            slots: slots
        )
    }

    /// Writes `proposed` to the press's split, capped so the owner
    /// keeps its floor and the rest its own (#933), and cues a
    /// truncated write on `focused`.
    func writeCappedBspSplit(
        _ press: BspSplitPress,
        proposed: Double,
        axis: String,
        space: Space,
        focused: WindowID?
    ) {
        let split = press.split
        let base = press.drawnRatio
        let global = Double(minWindowSize(in: space).on(axis: axis))
        let lowMin = plannedMinSize(of: split.owner, axis: axis)
        let rest = BspLayout.restMinimum(
            of: split,
            windows: press.tiled,
            in: press.context
        ) { plannedMinSize(of: $0, axis: axis) }
        let outcome = SplitDomain.cappedRatioWrite(
            proposed,
            base: base,
            available: split.available,
            minLow: lowMin,
            minHigh: rest.size
        )
        writeBspSplit(
            Self.storedBspRatio(outcome.value),
            owner: split.owner,
            sideBySide: split.sideBySide,
            for: space.id
        )
        guard outcome.clamped, let focused else { return }
        // A ratio moved down ran into the owner's floor, one moved up
        // into the rest's.
        let bindingFirst = proposed < base
        let restCarrier = rest.carrier.flatMap {
            plannedMinSize(of: $0, axis: axis) > global ? $0 : nil
        }
        reportResizeRefusal(
            focused: focused,
            bindingCarrier: bindingFirst
                ? (lowMin > global ? split.owner : nil) : restCarrier,
            fallbackAnchor: bindingFirst ? split.owner : split.rest.first,
            focusedIsBinding: bindingFirst
                ? split.owner == focused : split.rest.contains(focused),
            axis: axis
        )
    }

    /// A drag of `window`'s `edge` by `points` (its growth) moves
    /// the split behind that edge; an edge no split bounds moves
    /// nothing, the drop's filter having kept only inner edges.
    func resizeBspSplit(
        _ window: WindowID,
        axis: String,
        points: Double,
        edge: BspLayout.SplitEdge,
        space: Space
    ) {
        guard
            let press = bspSplit(
                of: window,
                axis: axis,
                edge: edge,
                space: space
            ), press.split.available > 0
        else { return }
        let before = press.slots[window].map {
            Double(axis == "x" ? $0.width : $0.height)
        }
        writeCappedBspSplit(
            press,
            proposed: press.drawnRatio
                + press.split.sign * points / press.split.available,
            axis: axis,
            space: space,
            focused: window
        )
        // A leading edge moved the split before the window; where the
        // window's own split runs along the axis too, it re-divides
        // the grown rest, so that split is set to keep the trailing
        // edge where the drag left it.
        guard edge == .leading, let before,
            let own = bspSplit(
                of: window,
                axis: axis,
                edge: .trailing,
                space: space
            ), own.split.available > 0
        else { return }
        writeCappedBspSplit(
            own,
            proposed: (before + points) / own.split.available,
            axis: axis,
            space: space,
            focused: window
        )
    }

    /// The cue for a press on a tiled window no split bounds on
    /// `axis`: a lone window divides nothing (the shared ratio still
    /// records the press, #383), a layout with no split on the axis
    /// divides only the other one, and a window spanning the axis has
    /// nothing to divide on it while the other axis does.
    func refuseBspNoSplit(
        _ window: WindowID,
        axis: String,
        delta: Double,
        span: Double,
        space: Space
    ) {
        guard let screen = TilingEngine.screen(for: space.id, in: state)
        else { return }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        let divides = BspLayout.divides(
            input.tiled,
            horizontal: axis == "x",
            in: input.context
        )
        if !divides.any {
            writeSharedBspRatio(
                delta: delta,
                axis: axis,
                span: span,
                space: space
            )
            refuseNothingToDivide(window, otherAxisDivides: false)
        } else if divides.axis {
            refuseNothingToDivide(window, otherAxisDivides: true)
        } else {
            refuseAxisAbsent(window, axis: axis)
        }
    }
}

/// A resolved BSP split and the layout it was read from (#3672).
struct BspSplitPress {
    let split: BspLayout.SplitOwner
    /// The mode the slots were laid out in.
    let mode: LayoutMode
    let tiled: [WindowID]
    let context: LayoutContext
    let slots: [WindowID: CGRect]

    /// The ratio the split is drawn at: its owner's share of what
    /// it divides, which a stored ratio outside the region's range
    /// is not (#1057's drawn-span base).
    var drawnRatio: Double {
        let stored = context.bspRatio(
            of: split.owner,
            sideBySide: split.sideBySide
        )
        guard split.available > 0, let slot = slots[split.owner]
        else { return stored }
        let length = Double(split.sideBySide ? slot.width : slot.height)
        return length / split.available
    }

    /// The slots with the split's ratio at `ratio`.
    func slots(at ratio: Double) -> [WindowID: CGRect] {
        var context = context
        context.bspSplits.set(
            KiwiCore.storedBspRatio(ratio),
            of: split.owner,
            sideBySide: split.sideBySide
        )
        return LayoutEngine.calculate(
            mode: mode,
            windows: tiled,
            context: context
        )
    }
}
