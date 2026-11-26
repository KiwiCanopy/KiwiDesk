/// Display order for Colours settings areas (#678, `ColorsCensusRenderTests`).
enum ColorsRowOrder {
    // MARK: - Colours & Animations

    /// The Shared look card's one row (#1752).
    static let sharedLookAtRest: [SettingKey] = [
        .colours(.lookAppliesTo)
    ]

    /// Context menu for user looks (#1684), the wallpaper items
    /// between Export and Delete (#3478).
    static let looksContextMenu: [SettingKey] = [
        .colours(.lookRename),
        .colours(.lookExport),
        .colours(.lookChooseWallpaper),
        .colours(.lookUseCurrentWallpaper),
        .colours(.lookRemoveWallpaper),
        .colours(.lookDelete),
    ]

    /// Context menu for user palettes (`ColorsCensusRenderTests`).
    static let palettesContextMenu: [SettingKey] = [
        .colours(.paletteRename),
        .colours(.paletteExport),
        .colours(.paletteDelete),
    ]

    /// The Finish group's rows, at rest (#2593, #3514): the Fill
    /// and the tint it greys, which need no glass, then the #1307
    /// master above the fade it greys (#2569), then the sheen's own
    /// row (#1644) — each switch directly above what it greys.
    static let glassRows: [SettingKey] = [
        .kiwishelf(.fillColor),
        .kiwishelf(.tintHubAndPlates),
        .colours(.liquidGlassMaster),
        .kiwishelf(.fillFade),
        .colours(.borderSheen),
    ]

    /// The Space switch card (#3218): how a switch shows itself
    /// and how the scroll step does (#2971); the slide's pace is
    /// the speed preset's (#3238).
    static let spaceSwitch: [SettingKey] = [
        .colours(.spaceTransition),
        .colours(.spaceScrollTransition),
    ]

    /// The Motion card's at-rest rows: the speed preset (#3238),
    /// then the window animations' master.
    static let motionAtRest: [SettingKey] = [
        .colours(.animationSpeed),
        .colours(.animationsMaster),
    ]

    /// Motion card disclosure rows.
    static let motionMore: [SettingKey] = [
        .colours(.animationsOnWindowResize),
        .colours(.animationsOnWindowSwap),
        .colours(.animationsOnRelayout),
        .colours(.animationsOnStateChange),
    ]

    // MARK: - Colors & glass (#2389)

    /// The Accent group (#1857): the hue the active Space, the
    /// focus border and the drag drop zone share — one half of each
    /// colour-vision pair, beside the Second accent's other half.
    static let accentRows: [SettingKey] = [
        .kiwishelf(.activeItemColor),
        .kiwishelf(.highlightColor),
        .kiwishelf(.hoverFillColor),
        .borders(.borderFocusedColor),
    ]

    /// The Second accent group (#1857), its follower last.
    static let secondAccentRows: [SettingKey] = [
        .spaceBar(.spaceBarFocusedItemColor),
        .spaceBar(.spaceBarFocusedHighlightColor),
    ]

    /// The shelf's own colours but the Fill, which sits in the
    /// Liquid Glass group (#1857, #2593).
    static let kiwishelfColorRows: [SettingKey] = [
        .kiwishelf(.itemColor),
        .kiwishelf(.hoverItemColor),
        .kiwishelf(.borderColor),
        .kiwishelf(.groupBadgeColor),
        .kiwishelf(.groupBadgeTextColor),
        .kiwishelf(.handleColor),
    ]

    /// The marks on windows that are not the focus (#1857).
    static let windowMarksRows: [SettingKey] = [
        .borders(.borderUnfocusedColor),
        .borders(.stickyColor),
        .borders(.floatingColor),
        .borders(.pocketColor),
    ]
}
