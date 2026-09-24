/// Display order for the Bars settings area (#678, `BarsCensusRenderTests`).
enum BarsRowOrder {
    /// KiwiShelf card, Show group: which bars the shelf carries.
    static let kiwishelfShow: [SettingKey] = [
        .spaceBar(.spaceBarEnabled),
        .layoutAppBar(.monocleAppBarEnabled),
        .layoutAppBar(.scrollingAppBarEnabled),
    ]

    /// KiwiShelf card, at rest below the Show group.
    static let kiwishelfAtRest: [SettingKey] = [
        .kiwishelf(.edge),
        .kiwishelf(.thickness),
        .kiwishelf(.alignment),
        .kiwishelf(.order),
        .kiwishelf(.share),
    ]

    /// KiwiShelf card, behind the Style disclosure.
    static let kiwishelfStyle: [SettingKey] = [
        .kiwishelf(.background),
        .kiwishelf(.backgroundFit),
        .kiwishelf(.cornerRoundness),
        .kiwishelf(.itemGap),
        .kiwishelf(.fontSizeAuto),
        .kiwishelf(.fontSize),
    ]

    /// KiwiShelf card, behind the Margins disclosure.
    static let kiwishelfMargins: [SettingKey] = [
        .kiwishelf(.outerMargin),
        .kiwishelf(.innerMargin),
    ]

    /// Space Bar card, at rest.
    static let spaceBarAtRest: [SettingKey] = [
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarHideEmpty),
    ]

    /// Space Bar card, behind the Style disclosure.
    static let spaceBarStyle: [SettingKey] = [
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarIconSource),
        .spaceBar(.spaceBarGlyphCap),
        .spaceBar(.spaceBarFrontAppTitleCap),
        .spaceBar(.spaceBarSpringDelay),
    ]

    /// App Bar card, at rest.
    static let appBarAtRest: [SettingKey] = [
        .appBar(.appBarGroupAdjacentWindows)
    ]

    /// App Bar card, behind the Style disclosure.
    static let appBarStyle: [SettingKey] = [
        .appBar(.appBarActiveIndicator),
        .appBar(.appBarContent),
        .appBar(.appBarTitleCap),
        .appBar(.appBarIconSource),
    ]
}
