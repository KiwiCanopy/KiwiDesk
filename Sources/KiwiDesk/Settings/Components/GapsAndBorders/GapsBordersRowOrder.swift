/// Display order for the Gaps & Borders area's rows (#678
/// Phase 3). Geometry only — every colour this feature draws
/// moved to Advanced Colours, so no colour row appears here.
///
/// The area's five containers each own one decision:
///
/// - `.gaps` — the outer and inner master sliders, each with a
///   per-edge / per-axis drawer beneath it.
/// - `.borders` — the two decisions all three strokes share,
///   each written to every stroke: the width master and the
///   Square/Rounded corner master (#754). The container spans
///   this area and Advanced Colours, which is where the same
///   group's tints render.
/// - `.focusBorder` — the ring: its unfocused twin, glow, and
///   the fit-layout-gaps action. The enable toggle owns the
///   container gate.
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

    /// The width master, then the Square/Rounded corner master.
    /// Each is a `(master)` row over several stored leaves and
    /// none of those leaves names a row of its own — the ring's
    /// width and corner style included, since #754 asks about
    /// all three strokes at once or not at all.
    static let borders: [SettingKey] = [
        .borders(.borderWidthMaster),
        .borders(.borderCornerMaster),
    ]

    /// The enable toggle first (it owns the container gate),
    /// then the unfocused twin, the glow, and the fit-gaps
    /// action. Width and Corners left for `.borders` in #754.
    static let focusBorder: [SettingKey] = [
        .borders(.borderEnabled),
        .borders(.borderUnfocusedEnabled),
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
    /// column's enable, border and fill. Alignment, border
    /// width and the corner radius all left the GUI in #754;
    /// what stays is what only a column can answer.
    static let dragAndDrop: [SettingKey] = [
        .borders(.dragGhostEnabled),
        .borders(.dragGhostBorder),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneEnabled),
        .borders(.dragDropZoneBorder),
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
    /// All five are: the gaps drawers, the shared card's two
    /// masters, the ring preview and its auto-gated glow group,
    /// the single sticky toggle, and the two-column drag
    /// layout are hand-built, not list-walked. So
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
