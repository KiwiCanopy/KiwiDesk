import CoreGraphics
import Foundation

/// Shared metric constants and pure resolve helpers, split
/// from SpaceBarStyle.swift (file-size ceiling). The Codable
/// conformance stays with the struct (synthesized `encode`
/// requires same-file).
extension SpaceBarStyle {
    /// Muted-badge background alpha over `item_color` on
    /// inactive spaces — one derivation shared by the runtime
    /// item view and the Settings preview.
    public static let mutedBadgeAlpha: CGFloat = 0.3

    /// The divider rules' alpha over `item_color` — the
    /// identifier↔glyphs rule and the front-app rule share it,
    /// like `mutedBadgeAlpha` above.
    public static let dividerAlpha: CGFloat = 0.4

    /// Valid drag-drop dwell bounds (ms): fast enough to feel
    /// responsive, slow enough not to spring by accident. Floored
    /// at 1000 so the sweep (which starts after a 0.5 s quiet
    /// pre-delay) still has visible fill time.
    public static let springDelayRange = 1000...4000

    /// Valid glyph-cap bounds (#376): 1 (a lone glyph + "+n",
    /// matching the PR #381 "0 is toggle-only, floor at 1" idiom)
    /// through 12 (past ~a dozen a status glyph row stops being
    /// scannable at any item size). A fixed clamp, not fit-derived —
    /// a display-dependent cap would resolve differently per screen
    /// and break the bar's otherwise-uniform model.
    public static let glyphCapRange = 1...12

    /// The glyph cap clamped to `glyphCapRange` — the driver reads
    /// this so a stored out-of-range value can't render nothing or
    /// an unscannable row.
    public var resolvedGlyphCap: Int {
        min(
            max(glyphCap, Self.glyphCapRange.lowerBound),
            Self.glyphCapRange.upperBound
        )
    }

    /// The front-segment title cap clamped to the range both
    /// bars share (`AppBarStyle.titleCapRange`) — one range, so
    /// the same window cannot read two lengths on one screen.
    public var resolvedTitleCap: Int {
        min(
            max(titleCap, AppBarStyle.titleCapRange.lowerBound),
            AppBarStyle.titleCapRange.upperBound
        )
    }

    /// The drag-drop spring dwell in seconds, clamped to
    /// `springDelayRange` — the coordinator and the sweep both
    /// read this so a stored out-of-range value can't misbehave.
    public var resolvedSpringDelay: TimeInterval {
        let ms = min(
            max(springDelay, Self.springDelayRange.lowerBound),
            Self.springDelayRange.upperBound
        )
        return TimeInterval(ms) / 1000
    }

    /// The identifier's font ladder: an explicit `font_size`
    /// wins; auto scales with half the strip depth, clamped to
    /// the depth minus padding.
    public func identifierFontSize(
        forDepth depth: CGFloat
    ) -> CGFloat {
        let base = fontSize > 0 ? fontSize : depth * 0.5
        return min(base, max(depth - 8, 8))
    }

    /// App glyphs sit a step below the identifier — defined as
    /// a ratio of ONE ladder so the item glyphs, the front-app
    /// glyph, and the identifier can never desync (two
    /// independent formulas rendered the same app at visibly
    /// different sizes in auto mode, QA 2026-07-19).
    public func glyphFontSize(
        forDepth depth: CGFloat
    ) -> CGFloat {
        identifierFontSize(forDepth: depth) * 0.9
    }

    /// Same %-resolve as `AppBarStyle.resolvedCornerRadius` —
    /// small duplicated helper over a shared protocol (§2.4).
    public func resolvedCornerRadius(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        max(0, min(cornerRoundness, 100)) / 100 * (thickness / 2)
    }
}
