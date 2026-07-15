import CoreGraphics

/// Pure geometry of one focus-border ring (#278). Turns a window
/// frame + width + corner style into the overlay window's frame
/// and the stroke's line width / corner radius, with no AppKit —
/// so the capped-inner rule is unit-testable in isolation.
///
/// Capped-inner: the stroke eats at most `min(width/2, 1)` pt of
/// window content (a hairline at any width) and grows the rest
/// outward into the gutter. At the 2 pt default that's 1 pt in /
/// 1 pt out — identical to a plain centered stroke — so the
/// shipped default look is unchanged while thick borders never
/// hide content.
struct BorderGeometry: Equatable {
    /// The overlay window's frame in AX (top-left) coordinates:
    /// the window grown by the ring's outward reach on every
    /// side, big enough to hold the whole stroke.
    let overlayFrame: CGRect
    /// The stroke's line width (pt) = the clamped border width.
    let lineWidth: CGFloat
    /// Corner radius (pt) of the stroke's centerline path, drawn
    /// in the overlay's own bounds inset by `lineWidth / 2`.
    let cornerRadius: CGFloat

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
        let w = min(
            BorderStyle.maxWidth,
            max(BorderStyle.minWidth, width)
        )
        // Inner overlap capped at 1 pt; the rest reaches outward.
        let inner = min(w / 2, 1)
        let outer = w - inner
        let radius: CGFloat
        switch cornerStyle {
        case .square:
            radius = 0
        case .rounded:
            // The centerline sits `w/2 - inner` outside the
            // window edge; a concentric rounded rect grows its
            // radius by the same offset.
            radius = max(0, systemRadius + (w / 2 - inner))
        }
        return BorderGeometry(
            overlayFrame: windowFrame.insetBy(
                dx: -outer,
                dy: -outer
            ),
            lineWidth: w,
            cornerRadius: radius
        )
    }
}
