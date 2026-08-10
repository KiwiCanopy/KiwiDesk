/// The Bars area's display order (turn 7a of the redesign,
/// #678 Phase 2). The census owns *placement* — which container
/// and tier each row sits in — but records no display order, so
/// the renderer declares it here as data.
///
/// `BarsCensusRenderTests` pins each list against the census:
/// every `.bars`-area key must appear in exactly the list its
/// placement names, so a census row added or moved without a
/// renderer update is a red test, not a silently missing
/// control.
enum BarsRowOrder {
    /// Space Bar card, at rest: does the bar exist, where, how
    /// thick, and the two content toggles.
    static let spaceBarAtRest: [SettingKey] = [
        .spaceBar(.spaceBarEnabled),
        .spaceBar(.spaceBarEdge),
        .spaceBar(.spaceBarThickness),
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarHideEmpty),
    ]

    /// Space Bar card, behind the Style disclosure. The
    /// Auto/value pairs are two census rows rendered as one
    /// `AutoGatedGroup`; the value key follows its toggle.
    static let spaceBarStyle: [SettingKey] = [
        .spaceBar(.spaceBarBackground),
        .spaceBar(.spaceBarLiquidGlass),
        .spaceBar(.spaceBarBackgroundFit),
        .spaceBar(.spaceBarAlignment),
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarIconSource),
        .spaceBar(.spaceBarCornerRoundness),
        .spaceBar(.spaceBarItemSizeAuto),
        .spaceBar(.spaceBarItemSize),
        .spaceBar(.spaceBarItemGap),
        .spaceBar(.spaceBarFontSizeAuto),
        .spaceBar(.spaceBarFontSize),
        .spaceBar(.spaceBarGlyphCap),
        .spaceBar(.spaceBarSpringDelay),
    ]

    /// App Bar card, at rest. No global on/off row — visibility
    /// is per layout, in `appBarShowIn` below.
    static let appBarAtRest: [SettingKey] = [
        .appBar(.appBarEdge),
        .appBar(.appBarThickness),
        .appBar(.appBarGroupAdjacentWindows),
        // The copy verb rides at rest, the adjust-gaps
        // precedent (owner 2026-08-10) — a one-shot action
        // nearly nobody found behind the drawer.
        .spaceBar(.copyAppearance),
    ]

    /// App Bar card, behind the Style disclosure.
    static let appBarStyle: [SettingKey] = [
        .appBar(.appBarBackground),
        .appBar(.appBarLiquidGlass),
        .appBar(.appBarBackgroundFit),
        .appBar(.appBarAlignment),
        .appBar(.appBarActiveIndicator),
        .appBar(.appBarContent),
        .appBar(.appBarIconSource),
        .appBar(.appBarCornerRoundness),
        .appBar(.appBarItemSizeAuto),
        .appBar(.appBarItemSize),
        .appBar(.appBarItemGap),
        .appBar(.appBarFontSizeAuto),
        .appBar(.appBarFontSize),
    ]

    /// The "Show it in" block, after the Style disclosure: the
    /// only layouts that can carry an App Bar. These own the
    /// `.appBar` container gate, so they stay live while the
    /// rows above grey.
    static let appBarShowIn: [SettingKey] = [
        .layoutAppBar(.monocleAppBarEnabled),
        .layoutAppBar(.scrollingAppBarEnabled),
    ]
}
