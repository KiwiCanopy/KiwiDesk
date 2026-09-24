import CoreGraphics
import Foundation

/// Metrics and resolution helpers for space bar styling (#376).
extension SpaceBarStyle {
    /// Muted-badge background alpha over `item_color` on inactive spaces.
    public static let mutedBadgeAlpha: CGFloat = 0.3

    /// Valid drag-drop dwell bounds in milliseconds.
    public static let springDelayRange = 1000...4000

    /// Valid glyph-cap bounds (#376): floor 1 (a lone glyph +
    /// "+n", the PR #381 "0 is toggle-only" idiom), ceiling 12. A
    /// fixed clamp, never fit-derived — a display-dependent cap
    /// would break the bar's uniform model.
    public static let glyphCapRange = 1...12

    /// Clamped glyph cap value (`glyphCapRange`).
    public var resolvedGlyphCap: Int {
        min(
            max(glyphCap, Self.glyphCapRange.lowerBound),
            Self.glyphCapRange.upperBound
        )
    }

    /// Front-app title length clamped to the shared range
    /// (`AppBarStyle.titleCapRange`).
    public var resolvedFrontAppTitleCap: Int {
        min(
            max(frontAppTitleCap, AppBarStyle.titleCapRange.lowerBound),
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
}
