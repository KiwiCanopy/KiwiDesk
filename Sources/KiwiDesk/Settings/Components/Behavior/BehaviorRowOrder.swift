/// Display order for the Behaviour area's rows (#678 Phase 3,
/// turn 9 — the last unconverted area). Two containers, both
/// hand-built cards in `BehaviorSection`:
///
/// - `.mouse` — the resize-action segment and the
///   follows-focus toggle.
/// - `.onQuit` — the quit grid's density stepper and its live
///   threshold summary.
///
/// Both are bespoke: each card mixes control kinds (a segmented
/// picker with its own help sheet, a stepper trailed by a derived
/// summary line), so nothing `ForEach`es these lists. They record
/// membership for the placement table and search while
/// `BehaviorCensusRenderTests` holds them equal to the census. A
/// row moves by editing the census; the order list follows.
enum BehaviorRowOrder {
    /// The mouse card, top to bottom.
    static let mouse: [SettingKey] = [
        .behaviour(.mouseResize),
        .behaviour(.mouseFollowsFocus),
    ]

    /// The on-quit card.
    static let onQuit: [SettingKey] = [
        .behaviour(.quitGridTargetDepth)
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .mouse: mouse,
        .onQuit: onQuit,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above — both of them, per the docstring at
    /// the top. A container that becomes a real `ForEach` leaves
    /// this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .mouse,
        .onQuit,
    ]
}
