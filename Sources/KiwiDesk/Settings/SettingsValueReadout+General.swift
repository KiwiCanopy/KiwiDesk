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
            .advancedConfigFile,
            .advancedEditLua, .advancedDiscardArrangement,
            .advancedResetAll, .onboardingDiscoveryShown,
            .iconPickerRecents, .onboardingOpenAtLogin,
            .advancedExportBackup, .advancedRestoreBackup:
            // no model path — never booked by the diff.
            // #606's pair joins the list for the same reason as
            // the reset actions: `(action) …` is not a model path,
            // so `SettingsDraftDiff` cannot book one. The
            // readout's totality guard filters these out and would
            // not have asked — the COMPILER did, which is the
            // better of the two nets.
            return []
        }
    }
}
