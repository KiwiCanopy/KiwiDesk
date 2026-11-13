/// Display order for Profiles area settings rows
/// (`ProfilesCensusRenderTests`, #678 Phase 3).
enum ProfilesRowOrder {
    /// Saved profile actions in visual order.
    static let savedProfiles: [SettingKey] = [
        .profiles(.profilesRename),
        .profiles(.isDefault),
        .profiles(.profilesAddScreenSetup),
        .profiles(.profilesLoad),
        .profiles(.profilesDelete),
    ]

    /// Desktop to profile bindings setting.
    static let profilesPerMacOSSpace: [SettingKey] = [
        .profiles(.profileBindings)
    ]

    /// Rows grouped by settings container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .savedProfiles: savedProfiles,
        .profilesPerMacOSSpace: profilesPerMacOSSpace,
    ]

    /// Containers rendered with custom bespoke views expanding dynamic
    /// instances.
    static let bespokeContainers: Set<SettingsContainer> = [
        .savedProfiles,
        .profilesPerMacOSSpace,
    ]
}
