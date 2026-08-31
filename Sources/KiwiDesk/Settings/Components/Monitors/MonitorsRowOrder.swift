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

    /// Containers rendered as bespoke views — here stronger than
    /// "hand-drawn": the placement container is a PICTURE whose
    /// rows are positioned by the real display arrangement, so
    /// there is no reading order for a `ForEach` to walk. Editing
    /// a list moves nothing on screen; a container that becomes a
    /// real `ForEach` leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spacePlacement,
        .pinnedToDisconnectedMonitors,
        .monitorFingerprints,
    ]
}
