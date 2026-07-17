import CoreGraphics

/// Pure geometry of one focus-border ring (#278). Turns a window
/// frame + width + corner style into the overlay window's frame
/// and the stroke's line width / corner radius, with no AppKit —
/// so the hidden-overlap rule is unit-testable in isolation.
///
/// `width` is always the visible thickness outside the target. The
/// renderer adds a fixed overlap behind the target; that hidden part
/// is not counted as border thickness. Ordering the overlay behind
/// the target masks the overlap and lets square rings fill the reveal
/// beneath rounded window corners.
struct BorderGeometry: Equatable {
    /// Where the ring sits in the window stack, which flips what the
    /// overlap *is* (#357). `below` masks the overlap behind the
    /// target (the AppKit fallback); `above` draws it on top of the
    /// target (the SkyLight fast path), so the overlap is visible and
    /// must stay a hairline.
    enum Order: Sendable, Equatable {
        case above
        case below
    }

    /// The overlay window's frame in AX (top-left) coordinates:
    /// the window grown by the ring's outward reach on every
    /// side, big enough to hold the whole stroke.
    let overlayFrame: CGRect
    /// The renderer's total stroke width: configured visible width
    /// plus the overlap hidden behind the target.
    let lineWidth: CGFloat
    /// Corner radius (pt) of the stroke's centerline path, drawn
    /// in the overlay's own bounds inset by `lineWidth / 2`.
    let cornerRadius: CGFloat

    /// **`below`-order only** (the AppKit fallback). Rounded needs a
    /// seam allowance deep enough to close the corner reveal on
    /// rounded windows, where a 1 pt tuck left a visible gap; square
    /// needs more still, to fill the harder 90° utility-window
    /// reveal. Both are masked behind the target — over-provisioning
    /// is free (the visible outer edge stays at `systemRadius +
    /// visible` regardless; a larger overlap only tucks the hidden
    /// inner edge deeper under the corner) — so the value is set by
    /// the widest reveal seen, not minimized. Raised 2.5 → 5 after a
    /// hairline gap persisted at small windows; the invariant is
    /// simply `≥ that reveal`. Never used by `above`-order, where the
    /// overlap is on-screen and must instead stay a hairline (see
    /// `aboveVisibleLapCap`).
    static let roundedHiddenOverlap: CGFloat = 5
    /// **`below`-order only.** Fixed rather than derived from
    /// `systemRadius` (the old `systemRadius · (1 − √2/2)` tuck):
    /// because the overlap is masked behind the target,
    /// over-provisioning is free and only *under*-provisioning
    /// re-opens the corner reveal this fills. 8 pt comfortably clears
    /// the square reveal for every macOS window radius seen to date;
    /// the invariant to keep is simply `squareHiddenOverlap ≥ that
    /// reveal` — raise it if a future radius bump ever exposes a
    /// corner gap.
    static let squareHiddenOverlap: CGFloat = 8
    /// **`above`-order cap.** With the ring stacked above the target
    /// the overlap laps *on top of* the window and is therefore
    /// visible, so over-provisioning is no longer free — a 5/8 pt
    /// band would smear across window content. Its only job here is
    /// to close the hairline seam where our circular corner arc meets
    /// the window's continuous-squircle corner, so it is capped to
    /// `min(visible / 2, aboveVisibleLapCap)` (the #311 hybrid): at
    /// most 1 pt, and never more than half the visible width so the
    /// ring stays predominantly outside the window. The outer edge
    /// stays at `systemRadius + visible` regardless (fit-gaps reach
    /// unchanged); only the inner edge moves.
    static let aboveVisibleLapCap: CGFloat = 1

    /// Builds the ring geometry for `windowFrame` (AX coords).
    /// `width` is clamped defensively; `systemRadius` is the
    /// shared window corner radius (rounded style) or ignored
    /// (square style → 0).
    static func compute(
        windowFrame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        order: Order = .below,
        systemRadius: CGFloat = GeometryUtils
            .systemWindowCornerRadius
    ) -> BorderGeometry {
        let visible = Self.clamp(width)
        let overlap = overlap(
            for: cornerStyle,
            order: order,
            visible: visible
        )
        let stroke = visible + overlap
        // The rounded stroke's outer edge stays concentric with the
        // target at `systemRadius + visible`. Square has no radius.
        let radius =
            cornerStyle == .square
            ? 0 : max(0, systemRadius + visible - stroke / 2)
        return BorderGeometry(
            overlayFrame: windowFrame.insetBy(
                dx: -visible,
                dy: -visible
            ),
            lineWidth: stroke,
            cornerRadius: radius
        )
    }

    /// How far the stroke reaches *outward* past the window edge
    /// (pt). `border.fit_gaps` sizes gaps from this so the gap math
    /// matches what the renderer actually draws.
    static func outwardReach(width: CGFloat) -> CGFloat {
        clamp(width)
    }

    /// The stroke depth beyond the visible width. `below`-order tucks
    /// it behind the target (a generous, masked seam allowance);
    /// `above`-order laps it onto the target (a visible hairline,
    /// capped) — see the constants for the full rationale.
    private static func overlap(
        for style: BorderStyle.CornerStyle,
        order: Order,
        visible: CGFloat
    ) -> CGFloat {
        switch order {
        case .below:
            switch style {
            case .rounded: roundedHiddenOverlap
            case .square: squareHiddenOverlap
            }
        case .above:
            min(visible / 2, aboveVisibleLapCap)
        }
    }

    private static func clamp(_ width: CGFloat) -> CGFloat {
        min(BorderStyle.maxWidth, max(BorderStyle.minWidth, width))
    }
}
