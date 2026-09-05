import AppKit
import CoreGraphics
import Foundation

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
