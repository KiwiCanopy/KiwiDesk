import KiwiDeskCore

/// General-area diff readout (non-model keys produce no rows, #606).
extension SettingsValueReadout {
    static func generalRows(
        _ key: GeneralKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        switch key {
        case .language, .appearance, .startAtLogin, .about,
            .advancedConfigFile,
            .advancedEditLua, .advancedDiscardArrangement,
            .advancedResetAll, .onboardingDiscoveryShown,
            .iconPickerRecents, .onboardingOpenAtLogin,
            .advancedExportBackup, .advancedRestoreBackup:
            // Non-model keys produce no diff rows.
            return []
        }
    }
}
