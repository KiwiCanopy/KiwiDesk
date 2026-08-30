/// Display order for the Bars settings area (#678, `BarsCensusRenderTests`).
enum BarsRowOrder {
    /// Space Bar card, at rest.
    static let spaceBarAtRest: [SettingKey] = [
        .spaceBar(.spaceBarEnabled),
        .spaceBar(.spaceBarEdge),
        .spaceBar(.spaceBarThickness),
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarHideEmpty),
    ]

    /// Space Bar card, behind the Style disclosure.
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
        .spaceBar(.spaceBarTitleCap),
        .spaceBar(.spaceBarSpringDelay),
    ]

    /// App Bar card, at rest.
    static let appBarAtRest: [SettingKey] = [
        .appBar(.appBarEdge),
        .appBar(.appBarThickness),
        .appBar(.appBarGroupAdjacentWindows),
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
        .appBar(.appBarTitleCap),
        .appBar(.appBarIconSource),
        .appBar(.appBarCornerRoundness),
        .appBar(.appBarItemSizeAuto),
        .appBar(.appBarItemSize),
        .appBar(.appBarItemGap),
        .appBar(.appBarFontSizeAuto),
        .appBar(.appBarFontSize),
    ]

    /// App Bar layout toggles ("Show it in").
    static let appBarShowIn: [SettingKey] = [
        .layoutAppBar(.monocleAppBarEnabled),
        .layoutAppBar(.scrollingAppBarEnabled),
    ]
}
