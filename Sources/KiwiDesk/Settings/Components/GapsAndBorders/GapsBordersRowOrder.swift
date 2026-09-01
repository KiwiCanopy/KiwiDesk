/// Display order for Gaps & Borders settings rows
/// (`GapsAndBordersCensusRenderTests`, #678 Phase 3, #754).
enum GapsBordersRowOrder {
    /// Outer and inner gap slider setting keys.
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

    /// Border width and corner master setting keys (#754).
    static let borders: [SettingKey] = [
        .borders(.borderWidthMaster),
        .borders(.borderCornerMaster),
    ]

    /// Focus border setting keys (#754).
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
        .borders(.stickyMark),
        .borders(.stickyDesktopReach),
    ]

    /// Drag-and-drop visual setting keys (#754).
    static let dragAndDrop: [SettingKey] = [
        .borders(.dragGhostEnabled),
        .borders(.dragGhostBorder),
        .borders(.dragGhostFill),
        .borders(.dragDropZoneEnabled),
        .borders(.dragDropZoneBorder),
        .borders(.dragDropZoneFill),
    ]

    /// Row order mapped by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .gaps: gaps,
        .borders: borders,
        .focusBorder: focusBorder,
        .stickyWindows: stickyWindows,
        .dragAndDrop: dragAndDrop,
    ]

    /// Containers rendered with bespoke SwiftUI views: the lists
    /// above record membership for the placement table and search,
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
