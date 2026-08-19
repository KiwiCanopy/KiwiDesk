import CoreGraphics

/// Pure resolve helpers split from AppBarStyle.swift (file-size
/// ceiling) — `SpaceBarStyle+Metrics` is the same seam on the
/// other bar. The Codable conformance stays with the struct.
extension AppBarStyle {
    /// The item font ladder: an explicit `font_size` wins;
    /// auto scales with the bar's cross dimension (its
    /// thickness), so a fat bar gets readable text and a slim
    /// one stays inside its strip. One resolution site shared
    /// by the item view, the slot measurement and the GUI
    /// preview so they can't drift —
    /// `SpaceBarStyle.identifierFontSize(forDepth:)` is the
    /// same shape on the other bar.
    public func resolvedFontSize(
        forThickness thickness: CGFloat
    ) -> CGFloat {
        if fontSize > 0 { return fontSize }
        return min(max(thickness * 0.42, 9), 28)
    }

    /// Valid title-cap bounds, shared by both bars — the Space
    /// Bar aliases this rather than declaring a second range, the
    /// way it already shares `BackgroundStyle` and `BarAlignment`.
    /// 8 at the floor because below it every title collapses to
    /// its first word and stops telling two windows of one app
    /// apart, which is the whole point of drawing a title; 80 at
    /// the ceiling because the slot clamps to a quarter of the bar
    /// long before that, so a larger number would silently do
    /// nothing. A fixed clamp, not fit-derived — the same
    /// reasoning as `glyphCapRange`: a display-dependent cap would
    /// resolve differently per screen and break the bar's
    /// otherwise-uniform model.
    public static let titleCapRange = 8...80

    /// The title cap clamped to `titleCapRange` — the driver reads
    /// this so a stored out-of-range value can't blank a title or
    /// hand the measurement an unbounded string.
    public var resolvedTitleCap: Int {
        min(
            max(titleCap, Self.titleCapRange.lowerBound),
            Self.titleCapRange.upperBound
        )
    }

    /// `title` cut to `cap` characters, tail-first, with an
    /// ellipsis standing in for what was dropped. The one copy
    /// both bars call: the App Bar's items and the Space Bar's
    /// front segment must agree, or the same window reads two
    /// lengths on one screen.
    ///
    /// Counts **Characters**, not UTF-16 units, so an emoji or a
    /// combining mark costs one the way the reader sees it — a
    /// ghostty tab titled "◐ app bar title truncation" must not
    /// spend two of its budget on the leading glyph. The ellipsis
    /// is not counted against `cap`: the cap answers "how much
    /// title", and making the marker eat a character of it would
    /// leave the cap describing something the user cannot see.
    public static func cappedTitle(
        _ title: String,
        to cap: Int
    ) -> String {
        guard title.count > cap else { return title }
        return String(title.prefix(cap)) + "…"
    }
}
