/// Display order for Colours settings areas (#678, `ColorsCensusRenderTests`).
enum ColorsRowOrder {
    // MARK: - Colours & Animations (the Simple area)

    /// Context menu for user palettes (`ColorsCensusRenderTests`).
    static let palettesContextMenu: [SettingKey] = [
        .colours(.paletteRename),
        .colours(.paletteExport),
        .colours(.paletteDelete),
    ]

    /// The Motion card's one at-rest row: the master switch.
    static let motionAtRest: [SettingKey] = [
        .colours(.animationsMaster)
    ]

    /// Motion card disclosure rows.
    static let motionMore: [SettingKey] = [
        .colours(.animationsOnSpaceChange),
        .colours(.animationsOnWindowResize),
        .colours(.animationsOnWindowSwap),
        .colours(.animationsOnRelayout),
        .colours(.animationsDurationMS),
    ]

    // MARK: - Advanced Colours (the Power-User area)

    /// Border swatches at rest (`AdvancedColorsSection`).
    static let bordersAtRest: [SettingKey] = [
        .borders(.borderFocusedColor),
        .borders(.borderUnfocusedColor),
        .borders(.stickyColor),
    ]

    /// Drag visuals twin columns (#231).
    static let dragGhostColumn: [SettingKey] = [
        .borders(.dragGhostBorderColor),
        .borders(.dragGhostFillColor),
    ]

    static let dragDropZoneColumn: [SettingKey] = [
        .borders(.dragDropZoneBorderColor),
        .borders(.dragDropZoneFillColor),
    ]

    /// Space Bar primary accent swatches.
    static let spaceBarAtRest: [SettingKey] = [
        .spaceBar(.spaceBarItemColor),
        .spaceBar(.spaceBarActiveItemColor),
        .spaceBar(.spaceBarFocusedItemColor),
    ]

    /// Space Bar additional color swatches.
    static let spaceBarMore: [SettingKey] = [
        .spaceBar(.spaceBarFillColor),
        .spaceBar(.spaceBarHighlightColor),
        .spaceBar(.spaceBarHoverFillColor),
        .spaceBar(.spaceBarHoverItemColor),
        .spaceBar(.spaceBarGroupBadgeColor),
        .spaceBar(.spaceBarGroupBadgeTextColor),
        .borders(.floatingColor),
    ]

    /// App Bar primary color swatches.
    static let appBarAtRest: [SettingKey] = [
        .appBar(.appBarFillColor),
        .appBar(.appBarHighlightColor),
    ]

    /// App Bar additional color swatches.
    static let appBarMore: [SettingKey] = [
        .appBar(.appBarItemColor),
        .appBar(.appBarActiveItemColor),
        .appBar(.appBarHoverFillColor),
        .appBar(.appBarHoverItemColor),
        .appBar(.appBarGroupBadgeColor),
        .appBar(.appBarGroupBadgeTextColor),
    ]
}
