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
    /// `StackLayout.loneMasterKeepsZone` asked from a command:
    /// the range is the SPLIT axis's on the space's own layout
    /// region (#449/#537), whichever axis the press came on.
    /// Traded: the raw region, where the engine judges the gapped
    /// one — the two answers differ only in a band under
    /// 2 × `min_window_size` plus the gaps, below any real
    /// display at the default floor, and `cappedRatioWrite`
    /// already clamps on the same raw span.
    func loneMasterKeepsZone(
        _ tiled: [WindowID],
        _ stack: StackParams,
        in space: Space
    ) -> Bool {
        StackLayout.loneMasterKeepsZone(
            tiled,
            params: stack,
            range: SplitDomain.effectiveRatioRange(
                available: layoutSpan(
                    of: space,
                    horizontal: stack.stackPosition.splitsHorizontally
                ),
                minSize: Double(
                    minWindowSize(in: space).along(
                        horizontal:
                            stack.stackPosition.splitsHorizontally
                    )
                )
            )
        )
    }

    /// The space's layout-region span along one axis — its OWN
    /// screen (#449) and the layout region, not the raw frame
    /// (#537) — the one span every resize write and cue divides
    /// by; the raw region, as `SplitDomain.cappedRatioWrite`
    /// already takes it.
    func layoutSpan(of space: Space, horizontal: Bool) -> Double {
        let bounds = TilingEngine.screen(for: space.id, in: state)
            .map { tiler.layoutBounds(on: $0, for: space) }
        return horizontal
            ? Double(bounds?.width ?? 1920)
            : Double(bounds?.height ?? 1080)
    }

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
        let stack = tiler.settings.resolvedStack(
            for: space,
            session: sessionRatios(of: space.id),
            flip: stackFlip(of: space.id)
        )
        let tiled = state.effectiveTiledMembers(of: space)
        let (master, stackZone) = StackLayout.partition(
            tiled,
            masterCount: stack.masterCount
        )
        let masterMin = plannedMinSize(
            of: master,
            axis: axis,
            in: space
        )
        let stackMin = plannedMinSize(
            of: stackZone ?? ArraySlice([]),
            axis: axis,
            in: space
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
        // A focus outside the tiled members is owed no
        // arrangement sentence; nothing live reaches this —
        // fullscreen is refused ahead (#1298), an active home
        // keeps its sticky (#1301, `ActiveHomeStickyMembershipTests`).
        guard tiled.contains(focused) else { return }
        // One term, not two: `partition` returns a nil zone
        // whenever the members fit in master, so an empty
        // master implies an empty `tiled` and is covered — and a
        // lone member kept at its zone (#1389) renders the ratio,
        // so the split DOES divide for it.
        if stackZone?.isEmpty ?? true,
            !loneMasterKeepsZone(tiled, stack, in: space)
        {
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

    /// The shared BSP ratio a press with no tiled focus writes —
    /// what every split without its own ratio takes (#3672), capped
    /// at the layout region's range (#383/#44/#458,
    /// `SessionRatioTests`), so an empty or unsplit space still
    /// records what a later split opens at.
    func writeSharedBspRatio(
        delta: Double,
        axis: String,
        span: Double,
        space: Space
    ) {
        let bsp = tiler.settings.resolvedBsp(
            for: space,
            session: sessionRatios(of: space.id)
        )
        let base = axis == "x" ? bsp.splitRatioH : bsp.splitRatioV
        let value = SplitDomain.cappedRatioWrite(
            base + delta / span,
            base: base,
            available: span,
            minSize: Double(minWindowSize(in: space).on(axis: axis))
        )
        let stored = Self.storedBspRatio(value)
        if axis == "x" {
            writeSplitRatioH(stored, for: space.id)
        } else {
            writeSplitRatioV(stored, for: space.id)
        }
    }

    /// The store's own 0.1...0.9 bound on a BSP ratio.
    nonisolated static func storedBspRatio(_ value: Double) -> Double {
        min(max(value, 0.1), 0.9)
    }

    /// Whether a press from `base` to `proposed` leaves the stored
    /// ratio where it is: at its bound, up to a hold's float drift.
    static func bspRatioSpent(_ base: Double, to proposed: Double) -> Bool {
        abs(storedBspRatio(proposed) - storedBspRatio(base)) < 1e-6
    }
}
