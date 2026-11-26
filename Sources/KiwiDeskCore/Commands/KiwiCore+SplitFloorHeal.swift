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
/// shares stay out (#944). Residue: the writer caps on the
/// EFFECTIVE members, so a visiting traveler's larger floor can
/// hold a proposal at its base — silent, and gone with the
/// traveler (the #944 horn).
extension KiwiCore {
    /// One "cannot fit" cue the heal has drawn: keyed per axis
    /// and overhanging window, so a retile storm says it once.
    /// Re-keyed with the other id-keyed ledgers on a native tab
    /// switch (`handleWindowRekeyed`).
    struct SplitFloorCue: Hashable {
        let axis: String
        let window: WindowID
    }

    func healSplitFloors() {
        // The cue draws on a window: only a space shown this pass
        // may say it, or the pill lands on a stashed frame and the
        // memo files an episode nobody saw.
        let shown = Set(
            tiler.visiblePlacements(state: state).map(\.space.id)
        )
        for space in state.workspaces.allSpaces
        where SplitOverflow.movesInward(space.mode) {
            healSpaceSplitFloors(
                of: space,
                shown: shown.contains(space.id)
            )
        }
    }

    private func healSpaceSplitFloors(of space: Space, shown: Bool) {
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
        guard !context.probesBeyondBounds,
            !healStandsDown(for: tiled)
        else { return }
        let bounds = tiler.layoutBounds(on: screen, for: space)
        let slots = LayoutEngine.calculate(
            mode: input.space.mode,
            windows: input.tiled,
            context: context
        )
        var cues: Set<SplitFloorCue> = []
        switch space.mode {
        case .bsp:
            // Each split heals its own ratio (#3672); a scrolled
            // chain's members are the run's, never a split's (#2542).
            for split in BspLayout.splits(of: input.tiled, in: context) {
                healBspSplit(
                    split,
                    space: space,
                    shown: shown,
                    input: input,
                    slots: slots,
                    cues: &cues
                )
            }
        case .stack:
            let stack = tiler.settings.resolvedStack(
                for: space,
                session: sessionRatios(of: space.id),
                flip: stackFlip(of: space.id)
            )
            let (master, stackZone) = StackLayout.partition(
                tiled,
                masterCount: stack.masterCount
            )
            guard let stackZone else { break }
            let axis =
                stack.stackPosition.splitsHorizontally ? "x" : "y"
            let gap =
                axis == "x"
                ? context.gaps.inner.horizontal
                : context.gaps.inner.vertical
            let available = Double(
                (axis == "x" ? context.usable.width : context.usable.height)
                    - gap
            )
            healSplit(
                axis: axis,
                low: Array(master),
                high: Array(stackZone),
                lowMin: plannedMinSize(of: master, axis: axis, in: space),
                highMin: plannedMinSize(of: stackZone, axis: axis, in: space),
                available: available,
                space: space,
                shown: shown,
                span: Double(axis == "x" ? bounds.width : bounds.height),
                context: context,
                cues: &cues,
                current: {
                    self.tiler.settings.resolvedStack(
                        for: $0,
                        session: self.sessionRatios(of: $0.id),
                        flip: self.stackFlip(of: $0.id)
                    ).masterRatio
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
    func healSplit(
        axis: String,
        low: [WindowID],
        high: [WindowID],
        lowMin: (size: Double, carrier: WindowID?),
        highMin: (size: Double, carrier: WindowID?),
        available: Double,
        space: Space,
        shown: Bool,
        span: Double,
        context: LayoutContext,
        cues: inout Set<SplitFloorCue>,
        current: (Space) -> Double,
        write: (Double, Double) -> Void
    ) {
        guard !low.isEmpty, !high.isEmpty else { return }
        let before = current(space)
        let verdict = SplitDomain.healedRatio(
            current: before,
            available: available,
            globalFloor: Double(context.minWindowSize.on(axis: axis)),
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
            write(ratio, span)
            let after = (state.workspaces[space.id]).map(current) ?? before
            // A store clamp or the writer's cap can land short of
            // the proposal: said once, when the store moved.
            guard after != before else { return }
            let landed = abs(after - ratio) < 0.000_001
            onLog(
                "split ratio healed for space \(space.id) (\(axis)): "
                    + String(format: "%.3f to %.3f", before, after)
                    + (landed
                        ? " to draw a learned floor"
                        : String(
                            format: ", short of the %.3f the floor needs",
                            ratio
                        ))
            )
        case .unfit(let bindingLow):
            let binding = bindingLow ? lowMin : highMin
            let sinking = bindingLow ? highMin : lowMin
            guard let overhanging = sinking.carrier,
                let anchor = binding.carrier
                    ?? (bindingLow ? low : high).first
            else { return }
            let cue = SplitFloorCue(axis: axis, window: overhanging)
            let said = splitFloorCues[space.id]?.contains(cue) ?? false
            // A hidden space carries an episode already said and
            // never opens one: the cue waits for the space to show.
            guard shown else {
                if said { cues.insert(cue) }
                return
            }
            cues.insert(cue)
            guard !said else { return }
            // The yield cannot fit: said once, on the window that
            // overhangs, the neighbour that binds marking itself —
            // and the frame lands inward (`SplitOverflow`).
            refuseFloorUnfitAtRetile(
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
