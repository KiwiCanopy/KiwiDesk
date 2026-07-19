import CoreGraphics

/// The shared background plate's frame — `plain`'s fill and the
/// Liquid Glass plate — for `tab_background_fit`
/// (QA 2026-07-19). Strip-local coordinates; pure math shared
/// by both bars so the two plates can't drift.
enum BarPlate {
    /// `full` spans the strip; `hug` wraps the content run plus
    /// one box gap of breathing room per end, clamped to the
    /// strip. Hug falls back to full while the run overflows
    /// and scrolls (`inset > 0` — content fills the strip, so
    /// there is nothing to hug) and for an empty run.
    nonisolated static func frame(
        strip: CGRect,
        runStart: CGFloat,
        runTotal: CGFloat,
        inset: CGFloat,
        gap: CGFloat,
        horizontal: Bool,
        fit: AppBarStyle.TabBackgroundFit
    ) -> CGRect {
        let full = CGRect(
            x: 0,
            y: 0,
            width: strip.width,
            height: strip.height
        )
        guard fit == .hug, inset == 0, runTotal > 0 else {
            return full
        }
        let axis = horizontal ? strip.width : strip.height
        let start = max(runStart - gap, 0)
        let end = min(runStart + runTotal + gap, axis)
        guard end > start else { return full }
        return horizontal
            ? CGRect(
                x: start,
                y: 0,
                width: end - start,
                height: strip.height
            )
            : CGRect(
                x: 0,
                y: start,
                width: strip.width,
                height: end - start
            )
    }
}
