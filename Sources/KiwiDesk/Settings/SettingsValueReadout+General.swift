import KiwiDeskCore

/// General-area rows. Every key here is app-internal
/// `UserDefaults` storage, a login-item service read, an
/// action, or a read-only row — none names a `settings.*` /
/// `config.*` model path, so the draft diff can never book one
/// and the readout has nothing to narrate.
extension SettingsValueReadout {
    static func generalRows(
        _ key: GeneralKey,
        old: GuiConfig,
        new: GuiConfig
    ) -> [SettingsDiffRow] {
        switch key {
        case .language, .appearance, .startAtLogin, .about,
            .advancedConfigFile, .advancedRestartOnCrash,
            .advancedEditLua, .advancedDiscardArrangement,
            .advancedResetAll, .onboardingDiscoveryShown,
            .iconPickerRecents, .onboardingOpenAtLogin:
            // no model path — never booked by the diff
            return []
        }
    }
}
