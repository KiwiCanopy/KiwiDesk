import CoreGraphics

/// Pure geometry for re-anchoring a floating window that crossed
/// displays (#444).
///
/// A float has no layout-computed frame: tiled windows arrive on
/// another monitor because the layout recomputes their frame on
/// the target display, but a float moved to a space shown
/// elsewhere keeps its old-screen coordinates and never visually
/// arrives. The re-anchor maps the window's center to the same
/// PROPORTIONAL position in the target's visible frame — bottom-
/// right stays bottom-right across different-sized displays
/// (2-monitor QA: an absolute corner offset read as "pulled to
/// the middle" on a bigger screen) — then confines the result
/// inside the target's visible frame.
///
/// All math is a pure function over AX visible frames — no AX,
/// no AppKit — so it is unit-testable (mirrors `FloatNudge`).
public enum FloatReanchor {
    /// `frame` re-centered at its proportional position inside
    /// `target`, confined fully within it (position only, size
    /// untouched; an axis larger than the target pins to its
    /// min edge — `FloatNudge.confine`). A degenerate source
    /// span maps to the target's center.
    public static func target(
        frame: CGRect,
        from source: CGRect,
        to target: CGRect
    ) -> CGRect {
        let relX =
            source.width > 0
            ? (frame.midX - source.minX) / source.width
            : 0.5
        let relY =
            source.height > 0
            ? (frame.midY - source.minY) / source.height
            : 0.5
        let moved = CGRect(
            x: target.minX + relX * target.width
                - frame.width / 2,
            y: target.minY + relY * target.height
                - frame.height / 2,
            width: frame.width,
            height: frame.height
        )
        return FloatNudge.confine(moved, to: target)
    }
}
