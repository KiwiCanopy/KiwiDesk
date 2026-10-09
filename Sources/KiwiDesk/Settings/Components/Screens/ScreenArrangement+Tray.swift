import CoreGraphics
import KiwiDeskCore

/// Dynamic height calculation for follows-main monitor arrangement tray.
extension ScreenArrangement {
    /// Computes tray height for the chip count: a constant clipped
    /// the heading once chips wrapped (owner 2026-08-04). Rows
    /// derive from the same `minChipWidth` the flow layout wraps
    /// on — a deliberate UPPER bound: too tall is empty space,
    /// too short clips.
    static func trayHeight(
        chips: Int,
        width: CGFloat
    ) -> CGFloat {
        guard chips > 1 else { return trayHeight }
        let usable = max(
            width - ScreenCardChips.cardPadding * 2,
            ScreenCardChips.minChipWidth
        )
        let step =
            ScreenCardChips.minChipWidth + ChipMetrics.spacing
        let perRow = max(
            1,
            Int((usable + ChipMetrics.spacing) / step)
        )
        let rows = max(
            1,
            Int((Double(chips) / Double(perRow)).rounded(.up))
        )
        guard rows > 1 else { return trayHeight }
        return trayHeight
            + CGFloat(rows - 1)
            * (ScreenCardChips.chipHeight + ChipMetrics.spacing)
    }
}
