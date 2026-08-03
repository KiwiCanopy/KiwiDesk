/// Display order for the Gaps & Borders area's rows (#678
/// Phase 3). Geometry only — every colour this feature draws
/// moved to Advanced Colours, so no colour row appears here.
///
/// The area's four containers each own one decision:
///
/// - `.gaps` — the outer and inner master sliders, each with a
///   per-edge / per-axis drawer beneath it.
/// - `.focusBorder` — the ring: its width, corner, unfocused
///   twin, glow, and the fit-layout-gaps action. The enable
///   toggle owns the container gate.
/// - `.stickyWindows` — the one on-window sticky mark toggle.
/// - `.dragAndDrop` — the shared corner radius plus the ghost
///   and drop-zone visual columns.
///
/// `GapsAndBordersCensusRenderTests` pins each list against the
/// census, so a row moves by editing the census rather than a
/// view.
enum GapsBordersRowOrder {
    /// Outer master then its four edges, inner master then its
    /// two axes — the order the editor stacks them.
    static let gaps: [SettingKey] = [
        .gaps(.outer),
        .gaps(.outerTop),
        .gaps(.outerBottom),
        .gaps(.outerLeft),
        .gaps(.outerRight),
        .gaps(.inner),
        .gaps(.innerHorizontal),
        .gaps(.innerVertical),
    ]

    /// The enable toggle first (it owns the container gate),
    /// then the ring's shape, its glow, and the fit-gaps action.
    static let focusBorder: [SettingKey] = [
        .borders(.borderEnabled),
        .borders(.borderUnfocusedEnabled),
        .borders(.borderWidth),
        .borders(.borderCorner),
        .borders(.borderGlow),
        .borders(.borderGlowSizeAuto),
        .borders(.borderGlowSize),
        .borders(.borderFitGapsExtraSpacing),
        .borders(.borderFitGaps),
    ]

    static let stickyWindows: [SettingKey] = [
        .borders(.stickyMark)
    ]

    /// The shared corner radius, then the ghost column, then the
    /// drop-zone column — each column's enable, border and fill.
    static let dragAndDrop: [SettingKey] = [
        .borders(.dragCornerRadius),
        .borders(.dragGhostEnabled),
        .borders(.dragGhostBorder),
        .borders(.dragGhostBorderWidth),
        .borders(.dragGhostBorderAlignment),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneEnabled),
        .borders(.dragDropZoneBorder),
        .borders(.dragDropZoneBorderWidth),
        .borders(.dragDropZoneBorderAlignment),
        .borders(.dragDropZoneFill),
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .gaps: gaps,
        .focusBorder: focusBorder,
        .stickyWindows: stickyWindows,
        .dragAndDrop: dragAndDrop,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above.
    ///
    /// All four are: the gaps drawers, the ring preview and its
    /// auto-gated glow group, the single sticky toggle, and the
    /// two-column drag layout are hand-built, not list-walked. So
    /// the lists exist to record membership for the placement
    /// table and search — and the guard holds that membership —
    /// but editing one moves nothing on screen (the edge `gui.md`
    /// warns about). A container that becomes a real `ForEach`
    /// leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .gaps,
        .focusBorder,
        .stickyWindows,
        .dragAndDrop,
    ]
}
