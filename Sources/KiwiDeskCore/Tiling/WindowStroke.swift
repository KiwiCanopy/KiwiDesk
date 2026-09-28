import CoreGraphics
import Foundation

/// The one shape every stroke KiwiDesk draws around a window takes
/// — the focus ring, the drag ghost and the drop zone (#1742): the
/// border's width and corner style, derived once and never stored
/// per stroke.
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
