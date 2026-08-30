import CoreGraphics

/// Calculates visible space chip capacity and overflow counts for display
/// cards (#678, #758).
enum MonitorCardChips {
    static let chipHeight: CGFloat = 22
    static let minChipWidth: CGFloat = 52
    static var spacing: CGFloat { ChipMetrics.spacing }
    static let cardPadding: CGFloat = 6
    static let headerHeight: CGFloat = 16
    static let trayHeaderHeight: CGFloat = 14
    /// Child spacing for chip stacks pinned in `MonitorsGateWiringTests`.
    static let stackSpacing: CGFloat = 2
    static let markerWidth: CGFloat = 34

    /// Returns usable chip area inside card geometry.
    static func chipArea(
        in size: CGSize,
        header: CGFloat = headerHeight
    ) -> CGSize {
        CGSize(
            width: max(0, size.width - cardPadding * 2),
            height: max(
                0,
                size.height - cardPadding * 2 - header
                    - stackSpacing
            )
        )
    }

    /// Number of chip rows fitting card geometry.
    static func rows(
        in size: CGSize,
        header: CGFloat = headerHeight
    ) -> Int {
        let area = chipArea(in: size, header: header)
        return max(
            1,
            Int((area.height + spacing) / (chipHeight + spacing))
        )
    }

    /// Maximum chips fitting card, optionally reserving space for `+n` marker.
    static func capacity(
        in size: CGSize,
        header: CGFloat = headerHeight,
        reservingMarker: Bool = false
    ) -> Int {
        let area = chipArea(in: size, header: header)
        let rows = rows(in: size, header: header)
        let usable =
            reservingMarker
            ? area.width - markerWidth - spacing : area.width
        let perRow = max(
            reservingMarker ? 0 : 1,
            Int((usable + spacing) / (minChipWidth + spacing))
        )
        return rows * perRow
    }

    /// Splits chips into visible items and overflow count
    /// (`MonitorCardChipsTests`).
    static func split<Chip>(
        _ chips: [Chip],
        in size: CGSize,
        header: CGFloat = headerHeight
    ) -> (shown: [Chip], overflow: Int) {
        let shown = OverflowSplit.shown(
            of: chips.count,
            fitting: capacity(in: size, header: header),
            withMarker: capacity(
                in: size,
                header: header,
                reservingMarker: true
            )
        )
        return (Array(chips.prefix(shown)), chips.count - shown)
    }
}
