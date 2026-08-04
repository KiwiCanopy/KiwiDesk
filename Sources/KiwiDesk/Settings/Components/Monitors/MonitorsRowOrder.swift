/// Display order for the Monitors area's rows (#678 Phase 3,
/// turn 13b). Three containers, all hand-built:
///
/// - `.spacePlacement` — the picture: one card per connected
///   display, the dashed follows-main tray, and the banner that
///   replaces both while there is no live geometry to draw.
/// - `.pinnedToDisconnectedMonitors` — one row per pin waiting on
///   a monitor that is not attached.
/// - `.monitorFingerprints` — one read-only row per display.
///
/// All three are bespoke, and here the reason is stronger than
/// "hand-drawn": the placement container is a PICTURE. Its rows
/// are positioned by the real display arrangement
/// (`MonitorArrangement`), so there is no reading order for a
/// `ForEach` to walk — a card's place on screen is where its
/// monitor is on the desk. The lists record membership for the
/// placement table and search, and
/// `MonitorsCensusRenderTests` holds them equal to the census.
enum MonitorsRowOrder {
    /// The banner leads: while it surfaces it is the only thing
    /// in this container, standing in for the cards it replaces.
    /// Then the cards, then the tray that hangs off one of them.
    static let spacePlacement: [SettingKey] = [
        .monitors(.placementUnavailable),
        .monitors(.spacePins),
        .monitors(.mainSpaces),
    ]

    /// One clear-back-to-automatic action per orphaned pin.
    static let pinnedToDisconnectedMonitors: [SettingKey] = [
        .monitors(.orphanPinClear)
    ]

    /// The read-only diagnostics drawer.
    static let monitorFingerprints: [SettingKey] = [
        .monitors(.fingerprints)
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .spacePlacement: spacePlacement,
        .pinnedToDisconnectedMonitors:
            pinnedToDisconnectedMonitors,
        .monitorFingerprints: monitorFingerprints,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above — all three, for the reason in the
    /// type's own docstring. A container that becomes a real
    /// `ForEach` leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .spacePlacement,
        .pinnedToDisconnectedMonitors,
        .monitorFingerprints,
    ]
}
