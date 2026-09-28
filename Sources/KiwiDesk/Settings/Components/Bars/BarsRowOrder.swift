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

    /// KiwiShelf card, behind Position's Each bar disclosure
    /// (#1731).
    static let kiwishelfEdges: [SettingKey] = [
        .kiwishelf(.spaceBarEdge),
        .kiwishelf(.appBarEdge),
    ]

    /// KiwiShelf card, behind the Style disclosure.
    static let kiwishelfStyle: [SettingKey] = [
        .kiwishelf(.background),
        .kiwishelf(.backgroundFit),
        .kiwishelf(.cornerRoundness),
        .kiwishelf(.border),
        .kiwishelf(.borderWidth),
        .kiwishelf(.highlightWidth),
        .kiwishelf(.itemGap),
        .kiwishelf(.glyphSizeAuto),
        .kiwishelf(.glyphSize),
        .kiwishelf(.fontSizeAuto),
        .kiwishelf(.fontSize),
        .kiwishelf(.fontFamily),
        .kiwishelf(.fontWeight),
        .kiwishelf(.iconSource),
    ]

    /// KiwiShelf card, behind the Margins disclosure.
    static let kiwishelfMargins: [SettingKey] = [
        .kiwishelf(.outerMargin),
        .kiwishelf(.innerMargin),
    ]

    /// Space Bar card — every row shown, each gate directly
    /// above what it gates (#1517); rows on the label axis
    /// first, the checkbox tier last (ui-patterns ▸ Row layout).
    static let spaceBar: [SettingKey] = [
        .spaceBar(.spaceBarItemLabel),
        .spaceBar(.spaceBarInactiveContent),
        .spaceBar(.spaceBarGlyphCap),
        .spaceBar(.spaceBarGlyphGap),
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarSpringDelay),
        .spaceBar(.spaceBarHideEmpty),
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarFrontAppTitleCap),
    ]

    /// App Bar card — every row shown, each gate directly above
    /// what it gates (#1517).
    static let appBar: [SettingKey] = [
        .appBar(.appBarContent),
        .appBar(.appBarTitleCap),
        .appBar(.appBarActiveIndicator),
        .appBar(.appBarGroupAdjacentWindows),
    ]
}
