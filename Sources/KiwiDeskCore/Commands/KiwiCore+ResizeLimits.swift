import AppKit
import CoreGraphics
import Foundation

/// Which size limit refused (part of) an interactive resize
/// (#933) — the structure the cues render, and what the test
/// seam (`BorderManager.onResizeRefusal`) observes, since the
/// drawn cues are display-gated and invisible headless.
enum ResizeRefusal: Equatable {
    /// A shrink stopped at the resized window's own effective
    /// minimum (`min_window_size`, or its learned app bound).
    case ownMinimum(WindowID)
    /// A grow stopped where `anchor` — a neighboring window —
    /// would drop below ITS effective minimum.
    case neighborMinimum(anchor: WindowID, focused: WindowID)
    /// A grow stopped at the resized window's own learned
    /// app-enforced maximum (#1055) — the app refuses to get
    /// bigger, so growing the slot further only overshoots.
    case ownMaximum(WindowID)
}

/// The effective-minimum resolution and the shared clamped
/// ratio writers used by every interactive resize path —
/// keyboard (`resize`) and mouse (`applyResizeAdjustment`)
/// alike, so the two cannot drift apart (#933; parity rule).
extension KiwiCore {
    /// The quantum for "the clamp truncated the request" on the
    /// point-valued paths (float, scrolling slot): AX frames
    /// wobble by sub-point rounding, so exact comparison would
    /// cue on noise. The ratio/weight paths need none — their
    /// outcomes report truncation from the domain math itself.
    static let resizeTruncationEpsilon: CGFloat =
        ScrollSlotDomain.truncationEpsilon

    /// One window's effective minimum on `axis`: the global
    /// `min_window_size` raised by the window's learned
    /// app-enforced bound (#677).
    func effectiveMinSize(
        of id: WindowID,
        axis: String
    ) -> Double {
        let bound = tiler.sizeBound(for: id)
        let appMin =
            (axis == "x" ? bound?.minWidth : bound?.minHeight)
            ?? 0
        return max(
            Double(tiler.settings.minWindowSize),
            Double(appMin)
        )
    }

    /// One window's learned app-enforced maximum on `axis`
    /// (#1055) — `effectiveMinSize`'s mirror, with one
    /// asymmetry: there is no configured global maximum the way
    /// `min_window_size` floors the minimum, so nil means
    /// unbounded rather than "the default".
    func effectiveMaxSize(
        of id: WindowID,
        axis: String
    ) -> Double? {
        let bound = tiler.sizeBound(for: id)
        return (axis == "x" ? bound?.maxWidth : bound?.maxHeight)
            .map(Double.init)
    }

    /// The largest effective minimum among `members` — a track
    /// or a stack zone spans every member on its axis, so the
    /// tightest window binds the whole group — plus the member
    /// that carries a LEARNED bound above the global floor, the
    /// honest anchor for a refusal cue. `carrier` is nil when
    /// only the global floor binds (every member is at the
    /// minimum at once). An EMPTY group still answers the
    /// global floor: the ratio caps protect the REGION, not
    /// only the windows currently in it (#383/#44 — an
    /// oversized drag must not ratchet the stored ratio to the
    /// store clamp), while the phantom-neighbor problem an
    /// empty side poses is the CUE's, which
    /// `reportResizeRefusal` stands down when no anchor
    /// exists.
    func effectiveMinSize(
        of members: some Collection<WindowID>,
        axis: String
    ) -> (size: Double, carrier: WindowID?) {
        let global = Double(tiler.settings.minWindowSize)
        var size = global
        var carrier: WindowID? = nil
        for member in members {
            let min = effectiveMinSize(of: member, axis: axis)
            if min > size {
                size = min
                carrier = member
            }
        }
        return (size, carrier)
    }

    /// Renders the refusal for a clamped write: the own-minimum
    /// cue when the binding window IS the resized one (or when
    /// only the global floor binds on a shrink), the
    /// neighbor-minimum cue anchored on the binding window
    /// otherwise — the #435 rule: the pill goes on the window
    /// that cannot move, not the trier.
    func reportResizeRefusal(
        focused: WindowID,
        bindingCarrier: WindowID?,
        fallbackAnchor: WindowID?,
        shrinking: Bool,
        axis: String
    ) {
        if shrinking {
            if let carrier = bindingCarrier, carrier != focused {
                // A group-mate's larger floor binds the shrink:
                // the mate is the window that cannot shrink.
                refuseGrowAtNeighborMinimum(
                    focused,
                    anchor: carrier,
                    axis: axis
                )
            } else {
                refuseShrinkAtMinimum(focused, axis: axis)
            }
            return
        }
        // A grow cue needs a real neighbor to point at; with no
        // binding-side member there is nothing being protected
        // and the cue stands down rather than naming a phantom
        // (a lone window's ratio still stops at the store
        // clamp, silently).
        guard let anchor = bindingCarrier ?? fallbackAnchor,
            anchor != focused
        else { return }
        refuseGrowAtNeighborMinimum(
            focused,
            anchor: anchor,
            axis: axis
        )
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
        guard outcome.clamped, let focused,
            deltaSign != 0
        else { return }
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
            shrinking: shrinking,
            axis: axis
        )
    }

    /// Two-sided capped BSP ratio write plus refusal cues — the
    /// one authority for the keyboard per-axis resize and the
    /// mouse `.bspRatioH`/`.bspRatioV` adjustments. Sides of
    /// the FIRST split resolve geometrically from the slots via
    /// the shared `MouseResize.bspSide` authority; each side's
    /// minimum is the max over its windows' effective minimums
    /// — a lower bound on what the side truly needs (its
    /// sub-splits can demand more), so this cap under-clamps
    /// but never over-clamps, and the per-region render clamp
    /// stays the net beneath it.
    func writeCappedBspRatio(
        proposed: Double,
        axis: String,
        span: Double,
        space: Space,
        focused: WindowID?,
        deltaSign: Double
    ) {
        let bsp = tiler.settings.resolvedBsp(for: space)
        let base =
            axis == "x" ? bsp.splitRatioH : bsp.splitRatioV
        let horizontal = axis == "x"
        let slots = tiler.calculatedFrames(state: state)
        let tiled = state.effectiveTiledMembers(of: space)
        var firstSide: [WindowID] = []
        var secondSide: [WindowID] = []
        if let screen = TilingEngine.screen(
            for: space.id,
            in: state
        ) {
            let bounds = tiler.layoutBounds(on: screen)
            for id in tiled {
                guard let slot = slots[id] else { continue }
                let side = MouseResize.bspSide(
                    slot: slot,
                    bounds: bounds,
                    horizontal: horizontal
                )
                if side > 0 {
                    firstSide.append(id)
                } else {
                    secondSide.append(id)
                }
            }
        }
        let lowMin = effectiveMinSize(of: firstSide, axis: axis)
        let highMin = effectiveMinSize(
            of: secondSide,
            axis: axis
        )
        let outcome = SplitDomain.cappedRatioWrite(
            proposed,
            base: base,
            available: span,
            minLow: lowMin.size,
            minHigh: highMin.size
        )
        let value = min(max(outcome.value, 0.1), 0.9)
        if axis == "x" {
            writeSplitRatioH(value, for: space.id)
        } else {
            writeSplitRatioV(value, for: space.id)
        }
        guard outcome.clamped, let focused,
            deltaSign != 0
        else { return }
        let focusedFirst = firstSide.contains(focused)
        let shrinking = deltaSign < 0
        let bindingFirst = shrinking ? focusedFirst : !focusedFirst
        let binding = bindingFirst ? lowMin : highMin
        let bindingSide = bindingFirst ? firstSide : secondSide
        reportResizeRefusal(
            focused: focused,
            bindingCarrier: binding.carrier,
            fallbackAnchor: bindingSide.first(where: {
                $0 != focused
            }),
            shrinking: shrinking,
            axis: axis
        )
    }

}
