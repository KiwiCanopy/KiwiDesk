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
    /// in the overlay's own bounds inset by `lineWidth / 2` plus
    /// `glowMargin`.
    let cornerRadius: CGFloat
    /// Extra outward room (pt) the overlay frame carries **beyond**
    /// the visible reach so a glow bloom isn't clipped by the
    /// window bounds (#358). `0` when glow is off — then the frame
    /// and draw math are identical to a plain ring. When on, the
    /// frame grows by this on every side and the stroke path is
    /// inset back by it, so the ring stays put and the margin is
    /// pure bloom space. Deliberately kept OUT of `outwardReach`:
    /// the soft bloom is allowed to bleed into the layout gap, so
    /// `border.fit_gaps` stays sized to the crisp stroke (#358
    /// ui-designer decision).
    let glowMargin: CGFloat

    /// **`below`-order only.** The one cushion beyond what corner
    /// geometry strictly requires, shared by both styles: rounded's arc
    /// already hugs the window's real radius, so its whole overlap is
    /// this cushion; square adds it on top of the mandatory
    /// `0.29 · radius` reveal (see `squareHiddenOverlap`). Kept to a
    /// sliver because a below-order ring lingers through a minimize
    /// genie — macOS reports the minimize only once the window lands at
    /// the Dock, so there is no earlier signal to hide on — and the
    /// shrinking window un-masks the overlap as a band whose thickness
    /// this sets. It only has to hide the hairline where our circular
    /// corner arc meets the window's continuous squircle, which the
    /// real per-window radius already all but closes (#361). Nudge up
    /// if a faint corner seam ever shows. Never used by `above`-order,
    /// where the overlap is on-screen and stays a hairline (see
    /// `aboveVisibleLapCap`).
    static let hiddenOverlapCushion: CGFloat = 0.1

    /// **`below`-order only.** The corner reveal a *square* ring must
    /// fill sits at `systemRadius · (1 − √2/2)` — the deepest point of
    /// a rounded window's corner, on the diagonal. Derived per window
    /// from its real radius (`BorderManager` reads it via SkyLight)
    /// plus `hiddenOverlapCushion`, rather than a fixed constant that
    /// could not scale and left a corner gap on large-radius windows
    /// (the old fixed 8 pt; #361). Under-provisioning re-opens the
    /// reveal in steady state. Never used by `above`-order, where the
    /// overlap is on-screen and stays a hairline (see
    /// `aboveVisibleLapCap`).
    static func squareHiddenOverlap(
        systemRadius: CGFloat
    ) -> CGFloat {
        let tuck = 1 - CGFloat(2).squareRoot() / 2
        return systemRadius * tuck + hiddenOverlapCushion
    }
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

    /// The glow bloom's blur radius (pt), and the amount the overlay
    /// frame grows on every side when glow is on so the halo isn't
    /// clipped (#358). Matches JankyBorders' fixed 10 pt
    /// `COLOR_STYLE_GLOW` shadow.
    static let glowBlur: CGFloat = 10

    /// Builds the ring geometry for `windowFrame` (AX coords).
    /// `width` is clamped defensively; `systemRadius` is the
    /// shared window corner radius (rounded style) or ignored
    /// (square style → 0). `glow` grows the overlay frame by
    /// `glowBlur` on every side so the bloom has room (#358).
    static func compute(
        windowFrame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        order: Order = .below,
        systemRadius: CGFloat = GeometryUtils
            .systemWindowCornerRadius,
        glow: Bool = false
    ) -> BorderGeometry {
        let visible = Self.clamp(width)
        let overlap = overlap(
            for: cornerStyle,
            order: order,
            visible: visible,
            systemRadius: systemRadius
        )
        let stroke = visible + overlap
        // The rounded stroke's outer edge stays concentric with the
        // target at `systemRadius + visible`. Square has no radius.
        let radius =
            cornerStyle == .square
            ? 0 : max(0, systemRadius + visible - stroke / 2)
        let margin = glow ? glowBlur : 0
        return BorderGeometry(
            overlayFrame: windowFrame.insetBy(
                dx: -(visible + margin),
                dy: -(visible + margin)
            ),
            lineWidth: stroke,
            cornerRadius: radius,
            glowMargin: margin
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
        visible: CGFloat,
        systemRadius: CGFloat
    ) -> CGFloat {
        switch order {
        case .below:
            switch style {
            case .rounded: hiddenOverlapCushion
            case .square:
                squareHiddenOverlap(systemRadius: systemRadius)
            }
        case .above:
            min(visible / 2, aboveVisibleLapCap)
        }
    }

    private static func clamp(_ width: CGFloat) -> CGFloat {
        min(BorderStyle.maxWidth, max(BorderStyle.minWidth, width))
    }
}
