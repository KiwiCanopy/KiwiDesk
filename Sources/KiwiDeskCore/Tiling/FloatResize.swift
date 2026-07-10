import CoreGraphics

/// Pure frame math for keyboard-resizing a FLOATING window:
/// `resize` on a floating focused window grows or shrinks the
/// window itself along the requested axis instead of nudging
/// the layout it does not participate in.
public enum FloatResize {
    /// The size a shrink stops at: `min_window_size` when set,
    /// never below 1 pt — AppKit rejects zero/negative frames,
    /// and a vanished window could not be grown back.
    public static func shrinkFloor(
        minSize: CGFloat
    ) -> CGFloat {
        max(minSize, 1)
    }

    /// The frame after growing along one axis by `delta`
    /// (negative shrinks), anchored at its origin — the
    /// top-left corner stays put, like a mouse drag of the
    /// bottom/right edge. The floor never exceeds the CURRENT
    /// size: a window already below `min_window_size` (floats
    /// are never layout-clamped, so that state is reachable)
    /// stays put on a shrink instead of jumping UP to the
    /// floor, and a grow grows by exactly `delta` (review).
    public static func resized(
        _ frame: CGRect,
        horizontal: Bool,
        delta: CGFloat,
        minSize: CGFloat
    ) -> CGRect {
        var result = frame
        if horizontal {
            result.size.width = max(
                frame.width + delta,
                min(shrinkFloor(minSize: minSize), frame.width)
            )
        } else {
            result.size.height = max(
                frame.height + delta,
                min(shrinkFloor(minSize: minSize), frame.height)
            )
        }
        return result
    }
}
