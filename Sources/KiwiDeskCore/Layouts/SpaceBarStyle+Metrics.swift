import CoreGraphics
import Foundation

/// Metrics and resolution helpers for space bar styling (#376).
extension SpaceBarStyle {
    /// Muted-badge background alpha over `item_color` on inactive spaces.
    public static let mutedBadgeAlpha: CGFloat = 0.3

    /// Divider rule alpha over `item_color`.
    public static let dividerAlpha: CGFloat = 0.4

    /// Valid drag-drop dwell bounds in milliseconds.
    public static let springDelayRange = 1000...4000

    /// Valid glyph-cap bounds (#376).
    public static let glyphCapRange = 1...12

    /// Clamped glyph cap value (`glyphCapRange`).
    public var resolvedGlyphCap: Int {
        min(
            max(glyphCap, Self.glyphCapRange.lowerBound),
            Self.glyphCapRange.upperBound
        )
    }

    /// Front-segment title cap clamped to shared range
    /// (`AppBarStyle.titleCapRange`).
    public var resolvedTitleCap: Int {
        min(
            max(titleCap, AppBarStyle.titleCapRange.lowerBound),
            AppBarStyle.titleCapRange.upperBound
        )
    }

    /// Drag-drop spring dwell in seconds clamped to `springDelayRange`.
    public var resolvedSpringDelay: TimeInterval {
        let ms = min(
            max(springDelay, Self.springDelayRange.lowerBound),
            Self.springDelayRange.upperBound
        )
        return TimeInterval(ms) / 1000
    }

    /// Calculated font size for space identifier based on bar depth.
    public func identifierFontSize(
        forDepth depth: CGFloat
    ) -> CGFloat {
        let base = fontSize > 0 ? fontSize : depth * 0.5
        return min(base, max(depth - 8, 8))
    }

    /// Scaled font size for app glyphs based on identifier size.
    public func glyphFontSize(
        forDepth depth: CGFloat
    ) -> CGFloat {
        identifierFontSize(forDepth: depth) * 0.9
    }

    /// Resolves corner radius proportional to bar thickness
    /// (`AppBarStyle.resolvedCornerRadius`).
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}
