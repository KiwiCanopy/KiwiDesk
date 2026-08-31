/// Row ordering and container census for Monitors settings
/// (`MonitorsCensusRenderTests`, #678 Phase 3, turn 13b).
enum MonitorsRowOrder {
    /// Space placement container rows (`MonitorArrangement`).
    static let spacePlacement: [SettingKey] = [
        .monitors(.placementUnavailable),
        .monitors(.spacePins),
        .monitors(.mainSpaces),
    ]

    /// Orphaned monitor pins container rows.
    static let pinnedToDisconnectedMonitors: [SettingKey] = [
        .monitors(.orphanPinClear)
    ]

    /// Diagnostics drawer container rows.
    static let monitorFingerprints: [SettingKey] = [
        .monitors(.fingerprints)
    ]

    /// All rows grouped by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .spacePlacement: spacePlacement,
        .pinnedToDisconnectedMonitors:
            pinnedToDisconnectedMonitors,
        .monitorFingerprints: monitorFingerprints,
    ]

    /// Containers rendered with custom views rather than generic ForEach.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spacePlacement,
        .pinnedToDisconnectedMonitors,
        .monitorFingerprints,
    ]
}
