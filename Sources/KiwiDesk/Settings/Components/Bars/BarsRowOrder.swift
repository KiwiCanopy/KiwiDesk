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
        .kiwishelf(.minimum),
    ]

    /// KiwiShelf card, behind the Style disclosure.
    static let kiwishelfStyle: [SettingKey] = [
        .kiwishelf(.background),
        .kiwishelf(.backgroundFit),
        .kiwishelf(.cornerRoundness),
        .kiwishelf(.highlightWidth),
        .kiwishelf(.itemGap),
        .kiwishelf(.fontSizeAuto),
        .kiwishelf(.fontSize),
        .kiwishelf(.iconSource),
    ]

    /// KiwiShelf card, behind the Margins disclosure.
    static let kiwishelfMargins: [SettingKey] = [
        .kiwishelf(.outerMargin),
        .kiwishelf(.innerMargin),
    ]

    /// Space Bar card — every row shown, each gate directly
    /// above what it gates (#1517).
    static let spaceBar: [SettingKey] = [
        .spaceBar(.spaceBarHideEmpty),
        .spaceBar(.spaceBarGlyphCap),
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarFrontAppTitleCap),
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarSpringDelay),
    ]

    /// App Bar card — every row shown, each gate directly above
    /// what it gates (#1517).
    static let appBar: [SettingKey] = [
        .appBar(.appBarContent),
        .appBar(.appBarTitleCap),
        .appBar(.appBarGroupAdjacentWindows),
        .appBar(.appBarActiveIndicator),
    ]
}
