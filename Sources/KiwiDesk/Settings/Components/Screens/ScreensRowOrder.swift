/// Row ordering and container census for Screens settings
/// (`ScreensCensusRenderTests`, #678 Phase 3, turn 13b).
enum ScreensRowOrder {
    /// Space placement container rows (`ScreenArrangement`).
    static let spacePlacement: [SettingKey] = [
        .screens(.placementUnavailable),
        .screens(.spacePins),
        .screens(.mainSpaces),
    ]

    /// Orphaned monitor pins container rows.
    static let pinnedToDisconnectedScreens: [SettingKey] = [
        .screens(.orphanPinClear)
    ]

    /// Diagnostics drawer container rows.
    static let screenFingerprints: [SettingKey] = [
        .screens(.fingerprints)
    ]

    /// All rows grouped by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .spacePlacement: spacePlacement,
        .pinnedToDisconnectedScreens:
            pinnedToDisconnectedScreens,
        .screenFingerprints: screenFingerprints,
    ]

    /// Containers rendered with custom views rather than generic ForEach.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spacePlacement,
        .pinnedToDisconnectedScreens,
        .screenFingerprints,
    ]
}
