/// Display order for the Bars settings area (#678, `BarsCensusRenderTests`).
enum BarsRowOrder {
    /// KiwiShelf card, Show group: the master, its Each bar
    /// drawer, the reveal, then the Space cue (#761, owner ruling
    /// 2026-10-21).
    static let kiwishelfShow: [SettingKey] = [
        .kiwishelf(.visibility),
        .kiwishelf(.revealStyle),
        .spaceBar(.spaceCue),
    ]

    /// KiwiShelf card, behind Show's Each bar disclosure (#761).
    static let kiwishelfShowEach: [SettingKey] = [
        .spaceBar(.spaceBarVisibility),
        .layoutAppBar(.monocleAppBarVisibility),
        .layoutAppBar(.scrollingAppBarVisibility),
    ]

    /// KiwiShelf card, at rest below the Show group: where the
    /// bars sit, coarse to fine.
    static let kiwishelfPlacement: [SettingKey] = [
        .kiwishelf(.edge),
        .kiwishelf(.alignment),
        .kiwishelf(.order),
        .kiwishelf(.minimum),
    ]

    /// KiwiShelf card, after a rule: how deep the strip is.
    static let kiwishelfDepth: [SettingKey] = [
        .kiwishelf(.thickness)
    ]

    /// KiwiShelf card, every at-rest row below the Show group.
    static var kiwishelfAtRest: [SettingKey] {
        kiwishelfPlacement + kiwishelfDepth
    }

    /// KiwiShelf card, behind Position's Each bar disclosure
    /// (#1731).
    static let kiwishelfEdges: [SettingKey] = [
        .kiwishelf(.spaceBarEdge),
        .kiwishelf(.spaceBarScreenEdge),
        .kiwishelf(.appBarEdge),
        .kiwishelf(.appBarScreenEdge),
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
        .spaceBar(.spaceBarGlyphSpan),
        .spaceBar(.spaceBarGlyphGap),
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarSpringDelay),
        .spaceBar(.spaceBarGroupAdjacent),
        .spaceBar(.spaceBarHideEmpty),
        .spaceBar(.spaceBarShowFrontApp),
        .spaceBar(.spaceBarFrontAppTitleCap),
    ]

    /// App Bar card — every row shown, each gate directly above
    /// what it gates (#1517).
    static let appBar: [SettingKey] = [
        .appBar(.appBarTitleCap),
        .appBar(.appBarActiveIndicator),
        .appBar(.appBarGroupAdjacentWindows),
    ]
}
