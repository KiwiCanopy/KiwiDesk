import KiwiDeskCore

/// General-area diff readout (non-model keys produce no rows, #606;
/// the `appWide.*` rows write at once, never through the draft,
/// #1741).
extension SettingsValueReadout {
    static func generalRows(
        _ key: GeneralKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        switch key {
        case .language, .appearance, .startAtLogin,
            .installUpdatesAutomatically, .refusalSound,
            .quitGridTargetDepth, .quitLayout,
            .advancedConfigFile,
            .advancedEditLua, .advancedDiscardArrangement,
            .advancedResetAll, .onboardingDiscoveryShown,
            .iconPickerRecents, .onboardingOpenAtLogin,
            .advancedExportBackup, .advancedRestoreBackup,
            .advancedExportLogRange, .advancedExportLog:
            // Non-model keys produce no diff rows.
            return []
        }
    }
}
