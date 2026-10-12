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

    /// The Glass card's rows: the #1307 master, and the sheen's
    /// own row directly beneath it (#1644).
    static let glassAtRest: [SettingKey] = [
        .colours(.liquidGlassMaster),
        .colours(.borderSheen),
    ]

    /// The Motion card's at-rest rows: how a Space switch shows
    /// itself and the slide's pace beneath it (#2143), then the
    /// window animations' master.
    static let motionAtRest: [SettingKey] = [
        .colours(.animationsSpaceChange),
        .colours(.animationsSpaceChangeDurationMS),
        .colours(.animationsMaster),
    ]

    /// Motion card disclosure rows.
    static let motionMore: [SettingKey] = [
        .colours(.animationsOnWindowResize),
        .colours(.animationsOnWindowSwap),
        .colours(.animationsOnRelayout),
        .colours(.animationsDurationMS),
    ]

    /// The shelf glide's rows in the Motion disclosure, outside the
    /// master's grey (#1838).
    static let motionShelf: [SettingKey] = [
        .colours(.animationsOnShelf),
        .colours(.animationsShelfDurationMS),
    ]

    // MARK: - Advanced Colours (the Power-User area)

    /// The Accent group (#1857): the hue the active Space, the
    /// focus border and the drag ghost share — one half of each
    /// colour-vision pair, beside the Second accent's other half.
    static let accentAtRest: [SettingKey] = [
        .kiwishelf(.activeItemColor),
        .kiwishelf(.highlightColor),
        .kiwishelf(.hoverFillColor),
        .borders(.borderFocusedColor),
        .borders(.dragGhostBorderColor),
        .borders(.dragGhostFillColor),
    ]

    /// The Second accent group (#1857), its follower last.
    static let secondAccentAtRest: [SettingKey] = [
        .spaceBar(.spaceBarFocusedItemColor),
        .borders(.dragDropZoneBorderColor),
        .borders(.dragDropZoneFillColor),
        .spaceBar(.spaceBarFocusedHighlightColor),
    ]

    /// The shelf's own colours — every one at rest (#1857).
    static let kiwishelfAtRest: [SettingKey] = [
        .kiwishelf(.fillColor),
        .kiwishelf(.itemColor),
        .kiwishelf(.hoverItemColor),
        .kiwishelf(.borderColor),
        .kiwishelf(.groupBadgeColor),
        .kiwishelf(.groupBadgeTextColor),
    ]

    /// The marks on windows that are not the focus (#1857).
    static let windowMarksAtRest: [SettingKey] = [
        .borders(.borderUnfocusedColor),
        .borders(.stickyColor),
        .borders(.floatingColor),
    ]
}
