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

    /// Rounded needs only a seam allowance; square needs enough
    /// depth to fill tighter utility-window corner reveals. Both
    /// are renderer-only and do not change the visible thickness.
    static let roundedHiddenOverlap: CGFloat = 1
    static let squareHiddenOverlap: CGFloat = 8

    /// Builds the ring geometry for `windowFrame` (AX coords).
    /// `width` is clamped defensively; `systemRadius` is the
    /// shared window corner radius (rounded style) or ignored
    /// (square style → 0).
    static func compute(
        windowFrame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        systemRadius: CGFloat = GeometryUtils
            .systemWindowCornerRadius
    ) -> BorderGeometry {
        let visible = Self.clamp(width)
        let overlap = hiddenOverlap(for: cornerStyle)
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

    private static func hiddenOverlap(
        for style: BorderStyle.CornerStyle
    ) -> CGFloat {
        switch style {
        case .rounded: roundedHiddenOverlap
        case .square: squareHiddenOverlap
        }
    }

    private static func clamp(_ width: CGFloat) -> CGFloat {
        min(BorderStyle.maxWidth, max(BorderStyle.minWidth, width))
    }
}
