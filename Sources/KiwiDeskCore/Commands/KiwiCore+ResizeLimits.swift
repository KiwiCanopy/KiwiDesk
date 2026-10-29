import AppKit
import CoreGraphics
import Foundation

/// The effective size resolution every interactive resize path
/// measures against, and the one place a clamped write decides
/// WHICH window its refusal names (#933/#435). The capped
/// writers that call them moved to `KiwiCore+RatioWriters`
/// when this file met the size ceiling.
extension KiwiCore {
    /// The quantum for "the clamp truncated the request" on the
    /// point-valued paths (float, scrolling slot): AX frames
    /// wobble by sub-point rounding, so exact comparison would
    /// cue on noise. The ratio/weight paths need none — their
    /// outcomes report truncation from the domain math itself.
    static let resizeTruncationEpsilon: CGFloat =
        ScrollSlotDomain.truncationEpsilon

    /// One window's effective minimum on `axis`: its layout's
    /// `min_window_size` (`minWindowSize(of:)`) raised by the
    /// window's learned app-enforced bound (#677).
    func effectiveMinSize(
        of id: WindowID,
        axis: String
    ) -> Double {
        max(
            Double(minWindowSize(of: id).on(axis: axis)),
            learnedMinSize(of: id, axis: axis)
        )
    }

    /// The floor a run plans a member at along `axis` — the
    /// effective minimum raised to the window's least refusal
    /// there (#2774), so a weight press clamps where the run
    /// would scroll. `LayoutContext.plannedFloor`'s clamp twin.
    func plannedMinSize(of id: WindowID, axis: String) -> Double {
        let refused = tiler.sizeBound(for: id)?
            .refusedFloor(horizontal: axis == "x")
        return max(effectiveMinSize(of: id, axis: axis), refused ?? 0)
    }

    /// One window's learned app-enforced minimum on `axis` (#677),
    /// 0 where none — the one reading both minimums take.
    func learnedMinSize(of id: WindowID, axis: String) -> Double {
        let bound = tiler.sizeBound(for: id)
        return Double(
            (axis == "x" ? bound?.minWidth : bound?.minHeight) ?? 0
        )
    }

    /// Whether the window's learned app floor, not the
    /// configured `min_window_size`, is what its effective
    /// minimum resolves to (#1261). `raisedBy` is a floor the
    /// clamp adds beside the setting — the scrolling slot's
    /// `ScrollSize.minPoints` — so a learned floor under it is
    /// not what bound. A refusal counts as the app's (#2774), the
    /// floor the run clamps stop at.
    func minimumIsAppBound(
        of id: WindowID,
        axis: String,
        raisedBy floor: Double = 0
    ) -> Bool {
        plannedMinSize(of: id, axis: axis)
            > max(
                Double(minWindowSize(of: id).on(axis: axis)),
                floor
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
    /// that carries a LEARNED bound above `space`'s floor, the
    /// honest anchor for a refusal cue. `carrier` is nil when
    /// only the configured floor binds (every member is at the
    /// minimum at once). An EMPTY group still answers `space`'s
    /// floor: the ratio caps protect the REGION, not
    /// only the windows currently in it (#383/#44 — an
    /// oversized drag must not ratchet the stored ratio to the
    /// store clamp), while the phantom-neighbor problem an
    /// empty side poses is the CUE's, which
    /// `reportResizeRefusal` stands down when no anchor
    /// exists.
    func effectiveMinSize(
        of members: some Collection<WindowID>,
        axis: String,
        in space: Space
    ) -> (size: Double, carrier: WindowID?) {
        // Every member takes the Space's own floor, never one
        // resolved again per window: a gap between the two would
        // read as a learned bound (#2237).
        groupMinSize(of: members, axis: axis, in: space) {
            learnedMinSize(of: $0, axis: axis)
        }
    }

    /// `effectiveMinSize` over a group, each member's learned
    /// floor raised to its least refusal on `axis` (#2774) — what
    /// a split heal and its press writers stop at, so one refusal
    /// moves the split that would otherwise overlap it.
    func plannedMinSize(
        of members: some Collection<WindowID>,
        axis: String,
        in space: Space
    ) -> (size: Double, carrier: WindowID?) {
        groupMinSize(of: members, axis: axis, in: space) {
            let refused = tiler.sizeBound(for: $0)?
                .refusedFloor(horizontal: axis == "x")
            return max(
                learnedMinSize(of: $0, axis: axis),
                Double(refused ?? 0)
            )
        }
    }

    private func groupMinSize(
        of members: some Collection<WindowID>,
        axis: String,
        in space: Space,
        learned: (WindowID) -> Double
    ) -> (size: Double, carrier: WindowID?) {
        var size = Double(minWindowSize(in: space).on(axis: axis))
        var carrier: WindowID? = nil
        for member in members {
            let min = learned(member)
            if min > size {
                size = min
                carrier = member
            }
        }
        return (size, carrier)
    }

    /// Renders the refusal for a clamped write: the own-minimum
    /// cue when the binding window IS the resized one (or when
    /// only the global floor binds on the side the focused
    /// window sits in), the neighbor-minimum cue anchored on
    /// the binding window otherwise — the #435 rule: the pill
    /// goes on the window that cannot move, not the trier.
    ///
    /// `focusedIsBinding` is the whole discriminator, and it is
    /// the caller's reading of its OWN partition rather than a
    /// direction re-derived here (#1259). A grow always runs
    /// into the other side, and a shrink into the focused
    /// window's own — unless the focused window takes no part
    /// in the split being written, which is exactly the case
    /// where the own-minimum wording names a window whose size
    /// the write could never have changed.
    func reportResizeRefusal(
        focused: WindowID,
        bindingCarrier: WindowID?,
        fallbackAnchor: WindowID?,
        focusedIsBinding: Bool,
        axis: String
    ) {
        if focusedIsBinding {
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
        // The cue needs a real window on the binding side to
        // point at; with no member there is nothing being
        // protected and it stands down rather than naming a
        // phantom (a lone window's ratio still stops at the
        // store clamp, silently).
        guard let anchor = bindingCarrier ?? fallbackAnchor,
            anchor != focused
        else { return }
        refuseGrowAtNeighborMinimum(
            focused,
            anchor: anchor,
            axis: axis
        )
    }
}
