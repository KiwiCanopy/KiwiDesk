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

    /// KiwiShelf colours at rest — the one set both bars draw
    /// (#1517).
    static let kiwishelfAtRest: [SettingKey] = [
        .kiwishelf(.fillColor),
        .kiwishelf(.itemColor),
        .kiwishelf(.activeItemColor),
        .kiwishelf(.highlightColor),
    ]

    /// KiwiShelf colours behind More, with the Space Bar's own
    /// focused-window ink and the floating mark.
    static let kiwishelfMore: [SettingKey] = [
        .kiwishelf(.hoverFillColor),
        .kiwishelf(.hoverItemColor),
        .kiwishelf(.groupBadgeColor),
        .kiwishelf(.groupBadgeTextColor),
        .kiwishelf(.borderColor),
        .spaceBar(.spaceBarFocusedItemColor),
        .borders(.floatingColor),
    ]
}
