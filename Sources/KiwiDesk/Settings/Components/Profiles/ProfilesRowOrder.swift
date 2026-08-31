/// Display order for Profiles area settings rows
/// (`ProfilesCensusRenderTests`, #678 Phase 3).
enum ProfilesRowOrder {
    /// Saved profile actions in visual order.
    static let savedProfiles: [SettingKey] = [
        .profiles(.profilesRename),
        .profiles(.isDefault),
        .profiles(.profilesLoad),
        .profiles(.profilesDelete),
    ]

    /// Desktop to profile bindings setting.
    static let profilesPerMacOSSpace: [SettingKey] = [
        .profiles(.profileBindings)
    ]

    /// Preset card actions in visual order (#859).
    static let presets: [SettingKey] = [
        .profiles(.presetsLayouts),
        .profiles(.presetsApply),
    ]

    /// Rows grouped by settings container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .savedProfiles: savedProfiles,
        .profilesPerMacOSSpace: profilesPerMacOSSpace,
        .presets: presets,
    ]

    /// Containers rendered as bespoke views: each expands one
    /// census key into a row per live instance, which an
    /// order-list `ForEach` cannot express. Editing a list moves
    /// nothing on screen; a container that becomes a real
    /// `ForEach` leaves this set in the same change.
    static let bespokeContainers: Set<SettingsContainer> = [
        .savedProfiles,
        .profilesPerMacOSSpace,
        .presets,
    ]
}
