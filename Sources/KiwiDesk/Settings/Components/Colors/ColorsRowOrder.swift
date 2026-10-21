/// Display order for Colours settings areas (#678, `ColorsCensusRenderTests`).
enum ColorsRowOrder {
    // MARK: - Colours & Animations (the Simple area)

    /// The Shared look card's one row (#1752).
    static let sharedLookAtRest: [SettingKey] = [
        .colours(.lookAppliesTo)
    ]

    /// Context menu for user looks (#1684).
    static let looksContextMenu: [SettingKey] = [
        .colours(.lookRename),
        .colours(.lookExport),
        .colours(.lookDelete),
    ]

    /// Context menu for user palettes (`ColorsCensusRenderTests`).
    static let palettesContextMenu: [SettingKey] = [
        .colours(.paletteRename),
        .colours(.paletteExport),
        .colours(.paletteDelete),
    ]

    /// The Liquid Glass group's rows: the #1307 master, and the
    /// sheen's own row directly beneath it (#1644).
    static let glassRows: [SettingKey] = [
        .colours(.liquidGlassMaster),
        .colours(.borderSheen),
    ]

    /// The Motion card's Space switch group: how a switch shows
    /// itself and the slide's pace beneath it (#2524).
    static let motionSpaceSwitch: [SettingKey] = [
        .colours(.spaceTransition),
        .colours(.spaceSlideDuration),
    ]

    /// The Motion card's at-rest rows: the Space switch group, then
    /// the window animations' master.
    static let motionAtRest: [SettingKey] =
        motionSpaceSwitch + [.colours(.animationsMaster)]

    /// Motion card disclosure rows.
    static let motionMore: [SettingKey] = [
        .colours(.animationsOnWindowResize),
        .colours(.animationsOnWindowSwap),
        .colours(.animationsOnRelayout),
        .colours(.animationsDurationMS),
    ]

    // MARK: - Colors & glass (#2389)

    /// The Accent group (#1857): the hue the active Space, the
    /// focus border and the drag ghost share — one half of each
    /// colour-vision pair, beside the Second accent's other half.
    static let accentRows: [SettingKey] = [
        .kiwishelf(.activeItemColor),
        .kiwishelf(.highlightColor),
        .kiwishelf(.hoverFillColor),
        .borders(.borderFocusedColor),
        .borders(.dragGhostBorderColor),
        .borders(.dragGhostFillColor),
    ]

    /// The Second accent group (#1857), its follower last.
    static let secondAccentRows: [SettingKey] = [
        .spaceBar(.spaceBarFocusedItemColor),
        .borders(.dragDropZoneBorderColor),
        .borders(.dragDropZoneFillColor),
        .spaceBar(.spaceBarFocusedHighlightColor),
    ]

    /// The shelf's own colours — every one at rest (#1857).
    static let kiwishelfColorRows: [SettingKey] = [
        .kiwishelf(.fillColor),
        .kiwishelf(.itemColor),
        .kiwishelf(.hoverItemColor),
        .kiwishelf(.borderColor),
        .kiwishelf(.groupBadgeColor),
        .kiwishelf(.groupBadgeTextColor),
    ]

    /// The marks on windows that are not the focus (#1857).
    static let windowMarksRows: [SettingKey] = [
        .borders(.borderUnfocusedColor),
        .borders(.stickyColor),
        .borders(.floatingColor),
    ]
}
