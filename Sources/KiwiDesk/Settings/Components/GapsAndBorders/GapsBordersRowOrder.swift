/// Display order for the Gaps & Borders area's rows (#678
/// Phase 3). Geometry only — every colour this feature draws
/// moved to Advanced Colours, so no colour row appears here.
///
/// The area's five containers each own one decision:
///
/// - `.gaps` — the outer and inner master sliders, each with a
///   per-edge / per-axis drawer beneath it.
/// - `.borders` — the decisions all three strokes share: the
///   one-width link, the master width and the corner radius
///   (#754). The container spans this area and Advanced
///   Colours, which is where the same group's tints render.
/// - `.focusBorder` — the ring: its corner, unfocused twin,
///   glow, and the fit-layout-gaps action. The enable toggle
///   owns the container gate.
/// - `.stickyWindows` — the one on-window sticky mark toggle.
/// - `.dragAndDrop` — the ghost and drop-zone visual columns.
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

    /// The link toggle first — it says what the two masters
    /// below it mean — then the width, then the corner radius.
    static let borders: [SettingKey] = [
        .borders(.linkedBorderWidth),
        .borders(.borderWidth),
        .borders(.dragCornerRadius),
    ]

    /// The enable toggle first (it owns the container gate),
    /// then the ring's own shape, its glow, and the fit-gaps
    /// action. Width left for `.borders` in #754.
    static let focusBorder: [SettingKey] = [
        .borders(.borderEnabled),
        .borders(.borderUnfocusedEnabled),
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

    /// The ghost column, then the drop-zone column — each
    /// column's enable, border, width and fill. Alignment left
    /// the GUI in #754 and the corner radius moved to
    /// `.borders`.
    static let dragAndDrop: [SettingKey] = [
        .borders(.dragGhostEnabled),
        .borders(.dragGhostBorder),
        .borders(.dragGhostBorderWidth),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneEnabled),
        .borders(.dragDropZoneBorder),
        .borders(.dragDropZoneBorderWidth),
        .borders(.dragDropZoneFill),
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .gaps: gaps,
        .borders: borders,
        .focusBorder: focusBorder,
        .stickyWindows: stickyWindows,
        .dragAndDrop: dragAndDrop,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above.
    ///
    /// All five are: the gaps drawers, the Borders card's
    /// link-plus-two-masters, the ring preview and its
    /// auto-gated glow group, the single sticky toggle, and the
    /// two-column drag layout are hand-built, not list-walked. So
    /// the lists exist to record membership for the placement
    /// table and search — and the guard holds that membership —
    /// but editing one moves nothing on screen (the edge `gui.md`
    /// warns about). A container that becomes a real `ForEach`
    /// leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .gaps,
        .borders,
        .focusBorder,
        .stickyWindows,
        .dragAndDrop,
    ]
}
