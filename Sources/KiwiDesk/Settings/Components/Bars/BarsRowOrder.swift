/// Display order for the Bars settings area (#678, `BarsCensusRenderTests`).
enum BarsRowOrder {
    /// KiwiShelf card, its head: the Show and Position masters,
    /// Position carrying the Each bar and Pocket drawer (#3612).
    static let kiwishelfShow: [SettingKey] = [
        .kiwishelf(.visibility),
        .kiwishelf(.edge),
    ]

    /// KiwiShelf card, behind Each bar and Pocket (#3612): the
    /// per-screen values, which the Screen or area picker heading
    /// the drawer edits, then each bar's Show and Position, by bar;
    /// the pocket's place along its edge closes the list (owner,
    /// 2026-11-18, #3445).
    static let kiwishelfEach: [SettingKey] = [
        .kiwishelf(.spaceBarScreenEdge),
        .kiwishelf(.spaceBarScreenVisibility),
        .kiwishelf(.appBarScreenEdge),
        .kiwishelf(.appBarScreenVisibility),
        .kiwishelf(.pocketScreenEdge),
        .spaceBar(.spaceBarVisibility),
        .kiwishelf(.spaceBarEdge),
        .layoutAppBar(.monocleAppBarVisibility),
        .layoutAppBar(.scrollingAppBarVisibility),
        .kiwishelf(.appBarEdge),
        .kiwishelf(.pocketVisibility),
        .kiwishelf(.pocketDragReveal),
        .kiwishelf(.pocketEdge),
        .kiwishelf(.pocketPosition),
    ]

    /// KiwiShelf card, under its "When a bar is out of view"
    /// heading (#3612): the menu bar icon, the handle's thickness
    /// (#3451) and the reveal (#761, owner ruling 2026-10-21).
    static let kiwishelfOutOfView: [SettingKey] = [
        .kiwishelf(.menuBarIcon),
        .kiwishelf(.handleThickness),
        .kiwishelf(.revealStyle),
    ]

    /// KiwiShelf card, behind the Durations disclosure under Reveal
    /// (owner ruling, 2026-10-21).
    static let kiwishelfDurations: [SettingKey] = [
        .colours(.animationsOnReveal),
        .colours(.animationsOnExpand),
    ]

    /// KiwiShelf card, after a rule: where the bars sit along the
    /// edge.
    static let kiwishelfPlacement: [SettingKey] = [
        .kiwishelf(.alignment)
    ]

    /// KiwiShelf card, after a rule: how deep the strip is.
    static let kiwishelfDepth: [SettingKey] = [
        .kiwishelf(.thickness)
    ]

    /// KiwiShelf card, every at-rest row below its head.
    static var kiwishelfAtRest: [SettingKey] {
        kiwishelfOutOfView + kiwishelfPlacement + kiwishelfDepth
    }

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
