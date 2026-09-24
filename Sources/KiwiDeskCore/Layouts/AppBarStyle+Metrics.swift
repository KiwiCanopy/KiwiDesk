import CoreGraphics

/// Metric resolution helpers for `AppBarStyle` (`SpaceBarStyle+Metrics`).
extension AppBarStyle {
    /// Title-cap bounds, shared by both bars. 8 at the floor —
    /// below it every title collapses to its first word and stops
    /// telling two windows apart; 80 at the ceiling — the slot
    /// clamps to a quarter of the edge long before that. A fixed
    /// clamp, never fit-derived: a display-dependent cap resolves
    /// differently per screen.
    public static let titleCapRange = 8...80

    /// The glyph's size against its slot's height: the full height
    /// read a touch heavy in manual QA. The Bars preview draws the
    /// same ratio (#1538), so it is one number.
    public static let glyphSlotRatio: CGFloat = 0.9

    /// Title cap clamped to `titleCapRange`.
    public var resolvedTitleCap: Int {
        min(
            max(titleCap, Self.titleCapRange.lowerBound),
            Self.titleCapRange.upperBound
        )
    }

    /// Truncates title to the cap, tail-first. Counts
    /// **Characters**, not UTF-16 units, so an emoji costs one the
    /// way the reader sees it; the ellipsis is not counted against
    /// the cap, which answers "how much title".
    public static func cappedTitle(
        _ title: String,
        to cap: Int
    ) -> String {
        guard title.count > cap else { return title }
        return String(title.prefix(cap)) + "…"
    }
}
