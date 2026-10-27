import KiwiDeskCore

/// Home card subtitles derived from plain values, so
/// `HomeCardContentTests` can drive them without a model.
extension HomeCardContent {
    /// Layout Standards' line: the minimum window size every layout
    /// shares, or that layouts differ (#2237).
    static func layoutSubtitle(_ settings: TilingSettings) -> String {
        let sizes = settings.minWindowSizes
        guard let width = sizes.shared(.width),
            let height = sizes.shared(.height)
        else {
            return L(
                "home.card.layout.subtitle_mixed",
                "Modes: %1$d · min window size per layout",
                LayoutMode.allCases.count
            )
        }
        return L(
            "home.card.layout.subtitle_size",
            "Modes: %1$d · min window %2$d × %3$d pt",
            LayoutMode.allCases.count,
            Int(width),
            Int(height)
        )
    }

    /// Screens' line: exactly one screen with nothing pinned
    /// invites a second one instead of reading "1 connected · 0";
    /// zero screens keep the counts, which stay true (#2690).
    static func screensSubtitle(
        displayCount: Int,
        pinCount: Int
    ) -> String {
        guard displayCount != 1 || pinCount > 0 else {
            return L(
                "home.card.monitors.subtitle_single",
                "One screen · connect another to place Spaces"
            )
        }
        return L(
            "home.card.monitors.subtitle",
            "%1$d connected · %2$d Spaces pinned",
            displayCount,
            pinCount
        )
    }
}
