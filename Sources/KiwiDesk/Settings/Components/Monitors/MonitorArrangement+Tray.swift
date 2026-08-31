import CoreGraphics
import KiwiDeskCore

/// Dynamic height calculation for follows-main monitor arrangement tray.
extension MonitorArrangement {
    /// Computes tray height dynamically for chip count and layout width.
    static func trayHeight(
        chips: Int,
        width: CGFloat
    ) -> CGFloat {
        guard chips > 1 else { return trayHeight }
        let usable = max(
            width - MonitorCardChips.cardPadding * 2,
            MonitorCardChips.minChipWidth
        )
        let step =
            MonitorCardChips.minChipWidth + ChipMetrics.spacing
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
            * (MonitorCardChips.chipHeight + ChipMetrics.spacing)
    }
}
