import CoreGraphics
import KiwiDeskCore

/// How tall the follows-main tray has to be for what it holds.
/// Split from `MonitorArrangement` when the derivation took
/// that file past the §2.1 ceiling — it is the one piece of
/// that arithmetic which reasons about CHIPS rather than about
/// displays.
extension MonitorArrangement {
    /// The tray's height for `chips` spaces at `width`.
    ///
    /// A CONSTANT 52 was wrong the moment a fourth space followed
    /// main: the chips wrap, and the box did not grow, so the
    /// second row pushed the tray's own heading out of the top of
    /// it (owner, 2026-08-04). Rows are derived from the same
    /// `minChipWidth` the flow layout wraps on, so the box and its
    /// contents agree by construction rather than by a guess.
    ///
    /// The row count is an UPPER bound, deliberately: real chips
    /// are usually wider than the minimum, so this can reserve a
    /// row that ends up unused. A tray one row too tall is a
    /// little empty space; one row too short clips a heading.
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
