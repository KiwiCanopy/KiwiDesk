import CoreGraphics

/// Pure geometry of one focus-border ring (#278). Turns a window
/// frame + width + corner style into the overlay window's frame
/// and the stroke's line width / corner radius, with no AppKit —
/// so the outset rule is unit-testable in isolation.
///
/// Pure outset (#303): the whole stroke is drawn *outside* the
/// window frame — one uniform outward offset of `width` on every
/// side, every corner style — so the ring never touches the
/// focused window's own content. macOS focus cues (keyboard
/// outline, VoiceOver, sidebar selection) all draw this way.
struct BorderGeometry: Equatable {
    /// The overlay window's frame in AX (top-left) coordinates:
    /// the window grown by the stroke width on every side, big
    /// enough to hold the whole outset stroke.
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
        let w = Self.clamp(width)
        // The overlay grows by `w` on each side, so its bounds
        // inset by `lineWidth / 2` (the centerline) sit `w / 2`
        // outside the window edge — a concentric rounded rect
        // grows its radius by the same offset. Square has none.
        let radius =
            cornerStyle == .square ? 0 : systemRadius + w / 2
        return BorderGeometry(
            overlayFrame: windowFrame.insetBy(dx: -w, dy: -w),
            lineWidth: w,
            cornerRadius: radius
        )
    }

    /// How far the stroke reaches *outward* past the window edge
    /// (pt) — the full width now that the stroke is pure outset.
    /// `border.fit_gaps` sizes gaps from this so the gap math
    /// matches what the renderer actually draws.
    static func outwardReach(width: CGFloat) -> CGFloat {
        clamp(width)
    }

    private static func clamp(_ width: CGFloat) -> CGFloat {
        min(BorderStyle.maxWidth, max(BorderStyle.minWidth, width))
    }
}
