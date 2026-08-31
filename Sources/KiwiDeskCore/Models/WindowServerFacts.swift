import CoreGraphics

/// Empirical WindowServer placement limits and constants (#139, #148).
public enum WindowServerFacts {
    /// WindowServer offscreen-visibility floor: an almost
    /// offscreen frame is clamped until ~this much stays visible.
    /// Probed 2026-07-10 (#148): ~32 pt bottom/diagonal, ~40 pt
    /// left/right; nothing may cross the top border (#139). An
    /// ask below the floor is unreachable — the OS lifts it, the
    /// ±2 pt retile tolerance never passes, and every retile
    /// re-issues the frame (#142). A deliberate offscreen sliver
    /// must derive from this value plus its own margin, so the
    /// next probe updates exactly one site.
    public static let visibilityFloor: CGFloat = 40
}
