import CoreGraphics

/// Pure geometry for re-anchoring a floating window that crossed
/// displays (#444).
///
/// A float has no layout-computed frame: tiled windows arrive on
/// another monitor because the layout recomputes their frame on
/// the target display, but a float moved to a space shown
/// elsewhere keeps its old-screen coordinates and never visually
/// arrives. The re-anchor translates the frame by the
/// source→target visible-frame offset — the window keeps its
/// position relative to the display it left — and confines the
/// result inside the target's visible frame.
///
/// All math is a pure function over AX visible frames — no AX,
/// no AppKit — so it is unit-testable (mirrors `FloatNudge`).
public enum FloatReanchor {
    /// `frame` translated by the source→target visible-frame
    /// origin offset, confined fully inside `target` (position
    /// only, size untouched; an axis larger than the target
    /// pins to its min edge — `FloatNudge.confine`).
    public static func target(
        frame: CGRect,
        from source: CGRect,
        to target: CGRect
    ) -> CGRect {
        let moved = frame.offsetBy(
            dx: target.minX - source.minX,
            dy: target.minY - source.minY
        )
        return FloatNudge.confine(moved, to: target)
    }
}
