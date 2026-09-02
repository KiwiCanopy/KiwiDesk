/// Display order for General area settings rows
/// (`GeneralCensusRenderTests`, #678 turn 14b).
enum GeneralRowOrder {
    /// Non-profile settings applying immediately.
    static let appliesImmediately: [SettingKey] = [
        .general(.language),
        .general(.appearance),
        .general(.startAtLogin),
    ]

    static let about: [SettingKey] = [
        .general(.about)
    ]

    /// Advanced configuration and reset rows in ascending severity
    /// (`GeneralSection+Reset`, #606).
    static let advanced: [SettingKey] = [
        .general(.advancedConfigFile),
        .general(.advancedEditLua),
        .general(.advancedExportBackup),
        .general(.advancedExportLogRange),
        .general(.advancedExportLog),
        .general(.advancedDiscardArrangement),
        .general(.advancedResetAll),
        .general(.advancedRestoreBackup),
    ]

    /// All rows grouped by container.
    static let byContainer: [SettingsContainer: [SettingKey]] = [
        .appliesImmediately: appliesImmediately,
        .about: about,
        .advanced: advanced,
    ]

    /// Containers rendered via bespoke view layouts rather than dynamic
    /// iteration (`gui.md`).
    static let bespokeContainers: Set<SettingsContainer> = [
        .appliesImmediately,
        .about,
        .advanced,
    ]
}
