import AppKit
import CoreGraphics
import Foundation

/// The retile-time heal of the split stores (#934/#1430) — the
/// Track floor heal's shape (#1355) one store over: the two bsp
/// split ratios and the stack master ratio are moved so a side
/// draws its members' LEARNED floor. Called from `KiwiCore.retile`
/// beside `healTrackSessionWeights`, inside the same forced-pass
/// scope, so it covers a window ARRIVING into a slot under its
/// floor and a resize that walked the split past the floor before
/// corroboration alike. The ruling — shared ratios may move for
/// a learned floor — is in `docs/design-decisions.md`.
///
/// Reads the LOCAL members (#944's traveler ruling), the render's
/// own `layoutInput`, and writes through the capped writers with
/// no focus, so the write clamps like a press and cues nothing;
/// stands down on a forced pass like every corroborated-bound
/// consumer (#1055). A mid-pass confirmation's residue pass takes
/// no heal, the one-retile latency #1355 accepts. Stack zone
/// shares stay out (#944).
extension KiwiCore {
    /// One "cannot fit" cue the heal has drawn: keyed per axis
    /// and overhanging window, so a retile storm says it once.
    struct SplitFloorCue: Hashable {
        let axis: String
        let window: WindowID
    }

    func healSplitFloors() {
        for space in state.workspaces.allSpaces
        where space.mode == .bsp || space.mode == .stack {
            healSpaceSplitFloors(of: space)
        }
    }

    private func healSpaceSplitFloors(of space: Space) {
        guard
            let screen = TilingEngine.screen(
                for: space.id,
                in: state
            )
        else { return }
        let tiled = state.localTiledMembers(of: space)
        guard tiled.count > 1,
            tiled.contains(where: { tiler.sizeBound(for: $0) != nil })
        else {
            // Nothing learned: whatever was cued has fit or gone,
            // so the episode ends here.
            splitFloorCues[space.id] = nil
            return
        }
        let input = tiler.layoutInput(
            state: state,
            space: space,
            screen: screen
        )
        let context = input.context
        guard !context.probesBeyondBounds else { return }
        let bounds = tiler.layoutBounds(on: screen)
        let slots = LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: context
        )
        var cues: Set<SplitFloorCue> = []
        switch space.mode {
        case .bsp:
            for axis in ["x", "y"] {
                let horizontal = axis == "x"
                let sides = BspSplit.sides(
                    of: tiled,
                    slots: slots,
                    bounds: bounds,
                    horizontal: horizontal
                )
                healSplit(
                    axis: axis,
                    low: sides.first,
                    high: sides.second,
                    space: space,
                    bounds: bounds,
                    context: context,
                    cues: &cues,
                    current: {
                        let bsp = self.tiler.settings.resolvedBsp(for: $0)
                        return horizontal
                            ? bsp.splitRatioH : bsp.splitRatioV
                    },
                    write: { ratio, span in
                        self.writeCappedBspRatio(
                            proposed: ratio,
                            axis: axis,
                            span: span,
                            space: space,
                            focused: nil
                        )
                    }
                )
            }
        case .stack:
            let stack = tiler.settings.resolvedStack(for: space)
            let (master, stackZone) = StackLayout.partition(
                tiled,
                masterCount: stack.masterCount
            )
            guard let stackZone else { break }
            let axis =
                stack.stackPosition.splitsHorizontally ? "x" : "y"
            healSplit(
                axis: axis,
                low: Array(master),
                high: Array(stackZone),
                space: space,
                bounds: bounds,
                context: context,
                cues: &cues,
                current: {
                    self.tiler.settings.resolvedStack(for: $0)
                        .masterRatio
                },
                write: { ratio, span in
                    self.writeCappedMasterRatio(
                        proposed: ratio,
                        span: span,
                        axis: axis,
                        space: space,
                        focused: nil,
                        deltaSign: 0
                    )
                }
            )
        default:
            break
        }
        splitFloorCues[space.id] = cues.isEmpty ? nil : cues
    }

    /// One split: `low` draws `ratio` of the span, `high` the
    /// rest. `current` reads the stored ratio off a Space value
    /// (re-read after the write, since the snapshot is stale);
    /// `write` is the capped writer, handed the raw region span
    /// every press hands it while the math divides the span the
    /// layout divides.
    private func healSplit(
        axis: String,
        low: [WindowID],
        high: [WindowID],
        space: Space,
        bounds: CGRect,
        context: LayoutContext,
        cues: inout Set<SplitFloorCue>,
        current: (Space) -> Double,
        write: (Double, Double) -> Void
    ) {
        guard !low.isEmpty, !high.isEmpty else { return }
        let lowMin = effectiveMinSize(of: low, axis: axis)
        let highMin = effectiveMinSize(of: high, axis: axis)
        let horizontal = axis == "x"
        let gap =
            horizontal
            ? context.gaps.inner.horizontal
            : context.gaps.inner.vertical
        let available = Double(
            (horizontal ? context.usable.width : context.usable.height)
                - gap
        )
        let before = current(space)
        let verdict = SplitDomain.healedRatio(
            current: before,
            available: available,
            globalFloor: Double(context.minWindowSize),
            low: .init(size: lowMin.size, learned: lowMin.carrier != nil),
            high: .init(
                size: highMin.size,
                learned: highMin.carrier != nil
            ),
            margin: StackLayout.minSizeMargin
        )
        switch verdict {
        case nil:
            return
        case .healed(let ratio):
            write(ratio, Double(horizontal ? bounds.width : bounds.height))
            let after = (state.workspaces[space.id]).map(current) ?? before
            guard after != before else { return }
            onLog(
                "split ratio healed for space \(space.id) (\(axis)): "
                    + String(format: "%.3f to %.3f", before, after)
                    + " to draw a learned floor"
            )
        case .unfit(let bindingLow):
            let binding = bindingLow ? lowMin : highMin
            let sinking = bindingLow ? highMin : lowMin
            guard let overhanging = sinking.carrier,
                let anchor = binding.carrier
                    ?? (bindingLow ? low : high).first
            else { return }
            let cue = SplitFloorCue(axis: axis, window: overhanging)
            cues.insert(cue)
            guard !(splitFloorCues[space.id]?.contains(cue) ?? false)
            else { return }
            // The yield cannot fit: said once, on the window that
            // overhangs, the neighbour that binds marking itself —
            // and the frame lands inward (`SplitOverflow`).
            refuseGrowAtNeighborMinimum(
                overhanging,
                anchor: anchor,
                axis: axis
            )
            onLog(
                "split floor unfit for space \(space.id) (\(axis)): "
                    + "\(overhanging) needs \(Int(sinking.size)) pt, "
                    + "\(anchor) holds the rest at its floor"
            )
        }
    }
}
