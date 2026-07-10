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
    /// bottom/right edge.
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
                shrinkFloor(minSize: minSize)
            )
        } else {
            result.size.height = max(
                frame.height + delta,
                shrinkFloor(minSize: minSize)
            )
        }
        return result
    }
}
