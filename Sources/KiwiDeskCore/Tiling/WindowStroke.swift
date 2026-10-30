import CoreGraphics
import Foundation

/// The border's stroke as the window strokes read it (#1742): the
/// drag markers take its corner style alone, their line widths
/// fixed by design (#2797), and store none of their own. The ring
/// derives its own radius per window (`BorderGeometry`).
public struct WindowStroke: Sendable, Equatable {
    /// Stroke width in points.
    public var width: CGFloat
    /// Corner radius in points: 0 for square corners.
    public var cornerRadius: CGFloat

    public init(width: CGFloat, cornerRadius: CGFloat) {
        self.width = width
        self.cornerRadius = cornerRadius
    }
}

extension TilingSettings {
    /// The stroke every window outline draws: the border's clamped
    /// width, and Square as no rounding while Rounded is the system
    /// window radius.
    public var windowStroke: WindowStroke {
        WindowStroke(
            width: borderStyle.clampedWidth,
            cornerRadius: borderStyle.cornerStyle == .square
                ? 0 : GeometryUtils.systemWindowCornerRadius
        )
    }
}
