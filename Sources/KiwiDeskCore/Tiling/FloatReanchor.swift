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
    /// Whether a window moved to `targetMode` needs the
    /// re-anchor at all (#498): every float-flagged window, and
    /// ANY window bound for a floating-MODE space — there the
    /// layout assigns no frames, so "the retile delivers" never
    /// happens and membership alone would leave it physically on
    /// the old display. Tiled windows bound for tiling spaces
    /// skip: the layout owns their frames.
    public static func eligible(
        isFloating: Bool,
        targetMode: LayoutMode?
    ) -> Bool {
        isFloating || targetMode == .floating
    }

    /// When `scaleSize` is on (#502, the default — see
    /// `TilingSettings.floatScaleOnDisplayChange`), the window's
    /// size is scaled by the per-axis ratio of the target to the
    /// source visible frame *before* it is re-centered — so a float
    /// keeps the same relative footprint across differently sized
    /// displays (a too-wide window shrinks to fit instead of
    /// overflowing the smaller screen's edge, which macOS lets it
    /// do on width while it half-clamps height). Off keeps the
    /// exact size (the pre-#502 behavior). A degenerate source span
    /// leaves that axis's size untouched — no ratio to apply.
    public static func target(
        frame: CGRect,
        from source: CGRect,
        to target: CGRect,
        scaleSize: Bool = false
    ) -> CGRect {
        let relX =
            source.width > 0
            ? (frame.midX - source.minX) / source.width
            : 0.5
        let relY =
            source.height > 0
            ? (frame.midY - source.minY) / source.height
            : 0.5
        let width =
            scaleSize && source.width > 0
            ? frame.width * target.width / source.width
            : frame.width
        let height =
            scaleSize && source.height > 0
            ? frame.height * target.height / source.height
            : frame.height
        let moved = CGRect(
            x: target.minX + relX * target.width - width / 2,
            y: target.minY + relY * target.height - height / 2,
            width: width,
            height: height
        )
        return FloatNudge.confine(moved, to: target)
    }
}
