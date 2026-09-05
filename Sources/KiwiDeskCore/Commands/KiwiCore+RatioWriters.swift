import AppKit
import CoreGraphics
import Foundation

/// The two capped ratio writers — the one authority each of the
/// keyboard `resize` verb and the mouse drag adjustment calls, so
/// the two paths cannot clamp or cue differently (#933; the
/// `writeCapped*` family is named by that prefix rather than by a
/// file, which is why it splits freely).
///
/// A refusal that is a fact about the ARRANGEMENT is decided
/// here rather than in the verb above (#1258): only this altitude
/// sees both input paths, and a verdict placed in the keyboard
/// verb left the same drag silent.
extension KiwiCore {
    /// Two-sided capped master-ratio write plus refusal cues —
    /// the one authority both the keyboard split-axis resize
    /// and the mouse `.masterRatio` adjustment call. `proposed`
    /// is the raw candidate ratio; `deltaSign` says whether the
    /// gesture GROWS (+) or SHRINKS (−) the focused window.
    func writeCappedMasterRatio(
        proposed: Double,
        span: Double,
        axis: String,
        space: Space,
        focused: WindowID?,
        deltaSign: Double
    ) {
        let stack = tiler.settings.resolvedStack(for: space)
        let tiled = state.effectiveTiledMembers(of: space)
        let (master, stackZone) = StackLayout.partition(
            tiled,
            masterCount: stack.masterCount
        )
        let masterMin = effectiveMinSize(of: master, axis: axis)
        let stackMin = effectiveMinSize(
            of: stackZone ?? ArraySlice([]),
            axis: axis
        )
        let outcome = SplitDomain.cappedRatioWrite(
            proposed,
            base: stack.masterRatio,
            available: span,
            minLow: masterMin.size,
            minHigh: stackMin.size
        )
        writeMasterRatio(
            min(max(outcome.value, 0.1), 0.9),
            for: space.id
        )
        guard let focused else { return }
        // A zone with no members means the split divides nothing
        // (#1258) — the layout hands the other zone the whole
        // region and ignores this ratio. Said on the FIRST press
        // like every arrangement fact, and said HERE rather than
        // in `resizeStack` because the mouse `.masterRatio` drag
        // arrives through this writer alone; measured before the
        // move, six keyboard shrinks on a one-window space drew
        // five "Minimum window size reached" pills on a window
        // filling the screen, and the drag drew nothing at all.
        // The WRITE still lands above: the store outlives the
        // window population (#383/#44/#458).
        if master.isEmpty || (stackZone?.isEmpty ?? true) {
            // The focused window's own zone may still divide on
            // the other axis, and that is the press to send it
            // to — but only where that zone's own orientation
            // crosses the split, which `master_count 2` with a
            // horizontal master does not.
            let column = StackLayout.column(
                containing: focused,
                in: tiled,
                masterCount: stack.masterCount
            )
            let orientation =
                master.contains(focused)
                ? stack.masterOrientation
                : stack.stackPosition.stackOrientation
            let weightAxis =
                orientation == .vertical ? "y" : "x"
            refuseNothingToDivide(
                focused,
                otherAxisDivides: weightAxis != axis
                    && (column?.count ?? 0) > 1
            )
            return
        }
        guard outcome.clamped, deltaSign != 0 else { return }
        let inMaster = master.contains(focused)
        let shrinking = deltaSign < 0
        // The binding side is the one whose minimum the write
        // ran into: the focused zone on a shrink, the other
        // zone on a grow.
        let bindingIsMaster = shrinking ? inMaster : !inMaster
        let binding = bindingIsMaster ? masterMin : stackMin
        let bindingZone: ArraySlice<WindowID> =
            bindingIsMaster ? master : (stackZone ?? ArraySlice([]))
        reportResizeRefusal(
            focused: focused,
            bindingCarrier: binding.carrier,
            fallbackAnchor: bindingZone.first(where: {
                $0 != focused
            }),
            focusedIsBinding: bindingZone.contains(focused),
            axis: axis
        )
    }

    /// Two-sided capped BSP ratio write plus refusal cues — the
    /// one authority for the keyboard per-axis resize and the
    /// mouse `.bspRatioH`/`.bspRatioV` adjustments. Sides of
    /// the FIRST split resolve geometrically from the slots via
    /// the shared `BspSplit.sides` authority, which also
    /// drops the windows the split cannot resize (#1259); each
    /// side's minimum is the max over its windows' effective
    /// minimums — a lower bound on what the side truly needs
    /// (its sub-splits can demand more), so this cap
    /// under-clamps but never over-clamps, and the per-region
    /// render clamp stays the net beneath it.
    ///
    /// This is the one writer whose focused window may be in
    /// NEITHER group: a stack zone and a track partition every
    /// member by membership, so their `focusedIsBinding` is a
    /// membership read. Here it has to be read off a partition
    /// the window may sit outside of.
    ///
    /// The write lands whatever the window population is — the
    /// ratio is a stored per-space value the caps protect the
    /// REGION of, not only the windows currently in it
    /// (#383/#44/#458, `SessionRatioTests`), so an empty or
    /// unsplit space still records what a later split opens at.
    /// Only the CUE reads the population.
    func writeCappedBspRatio(
        proposed: Double,
        axis: String,
        span: Double,
        space: Space,
        focused: WindowID?
    ) {
        let bsp = tiler.settings.resolvedBsp(for: space)
        let base =
            axis == "x" ? bsp.splitRatioH : bsp.splitRatioV
        let horizontal = axis == "x"
        let screen = TilingEngine.screen(for: space.id, in: state)
        let slots = tiler.calculatedFrames(state: state)
        let tiled = state.effectiveTiledMembers(of: space)
        // No display to classify against: the caps still hold on
        // the global floor, and nothing here can name a window.
        let sides = screen.map { screen in
            BspSplit.sides(
                of: tiled,
                slots: slots,
                bounds: tiler.layoutBounds(on: screen),
                horizontal: horizontal
            )
        }
        let lowMin = effectiveMinSize(
            of: sides?.first ?? [],
            axis: axis
        )
        let highMin = effectiveMinSize(
            of: sides?.second ?? [],
            axis: axis
        )
        let outcome = SplitDomain.cappedRatioWrite(
            proposed,
            base: base,
            available: span,
            minLow: lowMin.size,
            minHigh: highMin.size
        )
        writeBspRatio(outcome.value, axis: axis, space: space)
        guard let focused, let sides, let screen else { return }
        if sides.first.isEmpty, sides.second.isEmpty {
            // Nothing on this axis answers to the ratio. That is
            // a fact about the ARRANGEMENT rather than a limit
            // reached, so it is said on the first press like the
            // stack path's own no-parameter axis, not once the
            // clamp happens to bite — and only where the OTHER
            // axis DOES divide, which is what the sentence
            // claims. A space too small to split at all — one
            // window, an overflow pile — divides neither, and
            // naming an axis there would be the same wrong
            // sentence #1259 removed; #1258 owns the silence
            // that leaves.
            let across = BspSplit.sides(
                of: tiled,
                slots: slots,
                bounds: tiler.layoutBounds(on: screen),
                horizontal: !horizontal
            )
            if !across.first.isEmpty || !across.second.isEmpty {
                refuseAxisAbsent(focused, axis: axis)
            } else {
                // Neither axis divides: one window, or a pile.
                // #1259 left this wordless deliberately; #1258
                // is the string that fills it.
                // Reached only when the ACROSS axis is empty
                // too, so there is no other axis to send the
                // user to.
                refuseNothingToDivide(
                    focused,
                    otherAxisDivides: false
                )
            }
            return
        }
        guard outcome.clamped else { return }
        // A ratio that moved DOWN ran into the low side's
        // minimum and one that moved UP into the high side's —
        // read off the write's own direction, since the focused
        // window's side says nothing when it sits on neither. A
        // clamped outcome is never a standing-still write, so
        // the comparison always decides.
        let bindingFirst = proposed < base
        let binding = bindingFirst ? lowMin : highMin
        let bindingSide =
            bindingFirst ? sides.first : sides.second
        reportResizeRefusal(
            focused: focused,
            bindingCarrier: binding.carrier,
            fallbackAnchor: bindingSide.first(where: {
                $0 != focused
            }),
            focusedIsBinding: bindingSide.contains(focused),
            axis: axis
        )
    }

    /// The per-axis store write both paths above share, with the
    /// store's own 0.1...0.9 clamp applied once.
    private func writeBspRatio(
        _ value: Double,
        axis: String,
        space: Space
    ) {
        let stored = min(max(value, 0.1), 0.9)
        if axis == "x" {
            writeSplitRatioH(stored, for: space.id)
        } else {
            writeSplitRatioV(stored, for: space.id)
        }
    }
}
