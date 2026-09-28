import CoreGraphics
import Foundation

/// The drag markers' reading of the border's stroke (#1742): the
/// ghost and the drop zone draw the focus border's width and
/// corner style and store none of their own. The ring derives its
/// own radius per window (`BorderGeometry`).
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
