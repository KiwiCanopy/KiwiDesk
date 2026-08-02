/// Display order for the two colour areas (turn 12 of the
/// redesign, #678 Phase 3). Same split as `BarsRowOrder`: the
/// census owns *placement* — which area, container and tier each
/// row sits in — and records no display order, so the renderer
/// declares it here as data.
///
/// `ColorsCensusRenderTests` pins each list against the census:
/// every `.coloursAndMotion` / `.advancedColours` key must appear
/// in exactly the list its placement names, so a census row added
/// or retiered without a renderer update is a red test, not a
/// silently missing control.
enum ColorsRowOrder {
    // MARK: - Colours & Motion (the Simple area)

    /// The per-palette context menu, in menu order (Delete last
    /// and separated, being the destructive one).
    ///
    /// The shelf's AT-REST affordances get no list: they are a
    /// tile grid, a link hanging under one tile, a trailing
    /// add-tile and a header button — four different shapes, so
    /// a `ForEach` over keys would be a worse renderer, not a
    /// census-driven one. `ColorsCensusRenderTests` guards that
    /// half by hand-listing the census set instead, with the
    /// reason stated there.
    static let palettesContextMenu: [SettingKey] = [
        .colours(.paletteRename),
        .colours(.paletteExport),
        .colours(.paletteDelete),
    ]

    /// The Motion card's one at-rest row: the master switch.
    static let motionAtRest: [SettingKey] = [
        .colours(.animationsMaster)
    ]

    /// Behind the Motion card's disclosure — the four per-event
    /// toggles the master gates, then the duration they share.
    static let motionMore: [SettingKey] = [
        .colours(.animationsOnSpaceChange),
        .colours(.animationsOnWindowResize),
        .colours(.animationsOnWindowSwap),
        .colours(.animationsOnRelayout),
        .colours(.animationsDurationMS),
    ]

    // MARK: - Advanced Colours (the Nerd area)

    /// Borders: the two ring tints, then the sticky mark's.
    /// Three rows, so the group has no drawer — see
    /// `AdvancedColorsSection` for why the asymmetry with the
    /// bars is deliberate.
    static let bordersAtRest: [SettingKey] = [
        .borders(.borderFocusedColor),
        .borders(.borderUnfocusedColor),
        .borders(.stickyColor),
    ]

    /// Drag visuals, as the #231 twin columns. One list PER
    /// COLUMN, and each is what its column actually renders —
    /// a single combined list would be compared against the
    /// census by the parity guard while the renderer hand-listed
    /// its keys inline, so a fifth drag tint could be added to
    /// both the census and the list and still ship invisible.
    /// Four rows total, no drawer.
    static let dragGhostColumn: [SettingKey] = [
        .borders(.dragGhostBorderColor),
        .borders(.dragGhostFillColor),
    ]

    static let dragDropZoneColumn: [SettingKey] = [
        .borders(.dragDropZoneBorderColor),
        .borders(.dragDropZoneFillColor),
    ]

    /// The Space Bar's three-state accent ladder — the bar's
    /// defining signature, never behind a disclosure.
    static let spaceBarAtRest: [SettingKey] = [
        .spaceBar(.spaceBarItemColor),
        .spaceBar(.spaceBarActiveItemColor),
        .spaceBar(.spaceBarFocusedItemColor),
    ]

    /// The rest of the Space Bar's palette, behind "More
    /// colors": plate and highlight, the hover pair, then the
    /// badge cluster — the floating mark's tint rides that
    /// cluster, being the badge beside the group badge.
    static let spaceBarMore: [SettingKey] = [
        .spaceBar(.spaceBarFillColor),
        .spaceBar(.spaceBarHighlightColor),
        .spaceBar(.spaceBarHoverFillColor),
        .spaceBar(.spaceBarHoverItemColor),
        .spaceBar(.spaceBarGroupBadgeColor),
        .spaceBar(.spaceBarGroupBadgeTextColor),
        .borders(.floatingColor),
    ]

    /// The App Bar's two inline inks — the ones its preview
    /// strip reflects most.
    static let appBarAtRest: [SettingKey] = [
        .appBar(.appBarFillColor),
        .appBar(.appBarHighlightColor),
    ]

    /// The rest of the App Bar's palette, behind "More colors",
    /// in the Space Bar's order so the two grids read as one.
    static let appBarMore: [SettingKey] = [
        .appBar(.appBarItemColor),
        .appBar(.appBarActiveItemColor),
        .appBar(.appBarHoverFillColor),
        .appBar(.appBarHoverItemColor),
        .appBar(.appBarGroupBadgeColor),
        .appBar(.appBarGroupBadgeTextColor),
    ]
}
