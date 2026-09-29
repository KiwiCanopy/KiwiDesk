import CoreGraphics

/// Shared background plate frame math for bar background_fit.
enum BarPlate {
    /// Computes plate frame for `full` or `hug` background fit.
    /// Hug clamps to the strip, so an overflowing run's plate
    /// fills it; an empty run falls back to full.
    nonisolated static func frame(
        strip: CGRect,
        runStart: CGFloat,
        runTotal: CGFloat,
        gap: CGFloat,
        horizontal: Bool,
        fit: AppBarStyle.BackgroundFit
    ) -> CGRect {
        let full = CGRect(
            x: 0,
            y: 0,
            width: strip.width,
            height: strip.height
        )
        guard fit == .hug, runTotal > 0 else {
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

extension BarPlate {
    /// The span a run DRAWS, in the plate's coordinates (#1779):
    /// the run less each end item's own content inset — `insets`
    /// zero on a boxed shelf, where the box is what shows. What
    /// the section divider centres between; zero for no run.
    nonisolated static func content(
        strip: CGRect,
        runStart: CGFloat,
        runTotal: CGFloat,
        insets: ItemEnds,
        horizontal: Bool
    ) -> CGRect {
        guard runTotal > 0 else { return .zero }
        let start = runStart + insets.leading
        let extent = max(runTotal - insets.total, 0)
        return horizontal
            ? CGRect(x: start, y: 0, width: extent, height: strip.height)
            : CGRect(x: 0, y: start, width: strip.width, height: extent)
    }
}
