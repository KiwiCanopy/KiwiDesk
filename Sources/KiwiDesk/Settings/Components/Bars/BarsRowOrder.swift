/// Display order for the Bars settings area (#678, `BarsCensusRenderTests`).
enum BarsRowOrder {
    /// KiwiShelf card, Show group: the master, its Each bar
    /// drawer, the reveal, then the Space cue (#761, owner ruling
    /// 2026-10-21).
    static let kiwishelfShow: [SettingKey] = [
        .kiwishelf(.visibility),
        .kiwishelf(.revealStyle),
    ]

    /// KiwiShelf card, behind the Durations disclosure under Reveal
    /// (owner ruling, 2026-10-21).
    static let kiwishelfDurations: [SettingKey] = [
        .colours(.animationsRevealDurationMS),
        .colours(.animationsExpandDurationMS),
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
    ]

    /// KiwiShelf card, after a rule: how deep the strip is.
    static let kiwishelfDepth: [SettingKey] = [
        .kiwishelf(.thickness)
    ]

    /// KiwiShelf card, after a rule: where the pocket sits (#2678).
    static let kiwishelfPocket: [SettingKey] = [
        .kiwishelf(.pocketEdge),
        .kiwishelf(.pocketPosition),
    ]

    /// KiwiShelf card, every at-rest row below the Show group.
    static var kiwishelfAtRest: [SettingKey] {
        kiwishelfPlacement + kiwishelfDepth + kiwishelfPocket
    }

    /// KiwiShelf card, behind Position's Each bar disclosure
    /// (#1731).
    static let kiwishelfEdges: [SettingKey] = [
        .kiwishelf(.spaceBarEdge),
        .kiwishelf(.spaceBarScreenEdge),
        .kiwishelf(.appBarEdge),
        .kiwishelf(.appBarScreenEdge),
    ]

    /// KiwiShelf card, behind the Style disclosure; how two bars
    /// on one edge meet closes it (#2507).
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
        .kiwishelf(.order),
        .kiwishelf(.minimum),
    ]

    /// KiwiShelf card, behind the Margins disclosure.
    static let kiwishelfMargins: [SettingKey] = [
        .kiwishelf(.outerMargin),
        .kiwishelf(.innerMargin),
    ]

    /// Space Bar card, open: the choices, rows on the label axis
    /// first, the checkbox tier last (ui-patterns ▸ Row layout).
    static let spaceBar: [SettingKey] = [
        .spaceBar(.spaceBarItemLabel),
        .spaceBar(.spaceBarInactiveContent),
        .spaceBar(.spaceBarActiveIndicator),
        .spaceBar(.spaceBarGroupAdjacent),
        .spaceBar(.spaceBarHideEmpty),
        .spaceBar(.spaceBarShowFrontApp),
    ]

    /// Space Bar card, behind the Fine-tuning disclosure at its
    /// foot (#2507): the numbers, the title length first, directly
    /// under its gate Show front app.
    static let spaceBarTuning: [SettingKey] = [
        .spaceBar(.spaceBarFrontAppTitleCap),
        .spaceBar(.spaceBarGlyphSpan),
        .spaceBar(.spaceBarGlyphGap),
        .spaceBar(.spaceBarSpringDelay),
    ]

    /// App Bar card — every row shown, each gate directly above
    /// what it gates (#1517).
    static let appBar: [SettingKey] = [
        .appBar(.appBarTitleCap),
        .appBar(.appBarActiveIndicator),
        .appBar(.appBarGroupAdjacentWindows),
    ]
}
