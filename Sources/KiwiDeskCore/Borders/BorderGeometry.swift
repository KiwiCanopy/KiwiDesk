import CoreGraphics

/// Pure geometry of one focus-border ring (#278).
struct BorderGeometry: Equatable {
    /// Layering order in window stack determining overlap visibility (#357).
    enum Order: Sendable, Equatable {
        case above
        case below
    }

    /// Overlay window frame in AX coordinates.
    let overlayFrame: CGRect
    /// Total stroke width including overlap.
    let lineWidth: CGFloat
    /// Corner radius of stroke centerline path.
    let cornerRadius: CGFloat
    /// Outward margin for glow bloom expansion (#358).
    let glowMargin: CGFloat

    /// Below-order cushion to close squircle corner seam (#361).
    static let hiddenOverlapCushion: CGFloat = 0.1

    /// Corner reveal depth for square ring behind rounded window (#361).
    static func squareHiddenOverlap(
        systemRadius: CGFloat
    ) -> CGFloat {
        let tuck = 1 - CGFloat(2).squareRoot() / 2
        return systemRadius * tuck + hiddenOverlapCushion
    }

    /// Above-order visible overlap cap to avoid content smearing (#311).
    static let aboveVisibleLapCap: CGFloat = 1

    /// Computes ring geometry for `windowFrame` in AX coordinates (#358,
    /// #533).
    static func compute(
        windowFrame: CGRect,
        width: CGFloat,
        cornerStyle: BorderStyle.CornerStyle,
        order: Order = .below,
        systemRadius: CGFloat = GeometryUtils
            .systemWindowCornerRadius,
        glowBlur: CGFloat = 0
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
        let margin = max(0, glowBlur)
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
