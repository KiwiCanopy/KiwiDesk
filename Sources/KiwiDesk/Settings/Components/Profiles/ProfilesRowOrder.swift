/// Display order for the Profiles area's rows (#678 Phase 3,
/// turn 13a). Three containers, all hand-built:
///
/// - `.savedProfiles` — one row per saved profile, each carrying
///   the four actions below (rename, make default, load, delete).
/// - `.profilesPerMacOSSpace` — one row per native Desktop, its
///   profile menu behind the card's Show more.
/// - `.presets` — one card per built-in layout, grouped by screen
///   count.
///
/// All three are bespoke: none `ForEach`es its order list, because
/// every one of them expands ONE census key into a row per
/// instance (`ProfilesFamilyRows` is that half). So the lists
/// record membership for the placement table and search while
/// `ProfilesCensusRenderTests` holds them equal to the census. A
/// row moves by editing the census; the order list follows.
enum ProfilesRowOrder {
    /// The order a saved-profile row reads left to right: its
    /// name's rename affordance, the default marker, then the two
    /// actions that end the row.
    static let savedProfiles: [SettingKey] = [
        .profiles(.profilesRename),
        .profiles(.isDefault),
        .profiles(.profilesLoad),
        .profiles(.profilesDelete),
    ]

    /// The Desktop→profile bindings.
    static let profilesPerMacOSSpace: [SettingKey] = [
        .profiles(.profileBindings)
    ]

    /// Each preset card's Apply.
    static let presets: [SettingKey] = [
        .profiles(.presetsApply)
    ]

    /// Every row this area draws, by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .savedProfiles: savedProfiles,
        .profilesPerMacOSSpace: profilesPerMacOSSpace,
        .presets: presets,
    ]

    /// Containers drawn as BESPOKE views rather than a `ForEach`
    /// over the list above.
    ///
    /// All three are: each expands one census key into a row per
    /// live instance (a saved profile, a Desktop, a preset), which
    /// is exactly what an order-list `ForEach` cannot express. So
    /// the lists exist to record membership for the placement
    /// table and search — the guard holds that membership — but
    /// editing one moves nothing on screen. A container that
    /// becomes a real `ForEach` leaves this set in the same
    /// change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .savedProfiles,
        .profilesPerMacOSSpace,
        .presets,
    ]
}
