import CoreGraphics

/// Empirical WindowServer placement facts, probed against the
/// live OS. Shared value types so both `Layouts` (pure math)
/// and `Tiling` (the engine) can consume them without a
/// dependency edge between the two.
public enum WindowServerFacts {
    /// The WindowServer's offscreen-visibility floor: an
    /// (almost) fully offscreen frame is clamped back until
    /// roughly this much of it stays visible. Probed
    /// 2026-07-10 (#148): ~32 pt on bottom/diagonal asks,
    /// ~40 pt on left/right; partial overflow above the floor
    /// applies exactly; nothing may go above the top border
    /// at all (#139). An ask below the floor is unreachable —
    /// the OS lifts it, the ±2 pt retile tolerance never
    /// passes, and every retile re-issues the frame (#142,
    /// #148). Any deliberate offscreen sliver must derive
    /// from this value plus its own per-intent margin (the
    /// derived slivers may diverge), so the next probe
    /// updates exactly one site.
    public static let visibilityFloor: CGFloat = 40
}
