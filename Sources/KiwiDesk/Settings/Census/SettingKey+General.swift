/// App-wide General rows: language, login item, About,
/// Advanced maintenance actions, app-internal UserDefaults.

enum GeneralKey: String, CaseIterable, Hashable {
    case language = "UserDefaults.language"
    case appearance = "UserDefaults.appearance"
    case startAtLogin = "AutoStartManager (no stored pref)"
    case about = "(readonly) general.about"
    case advancedConfigFile = "(readonly) general.advanced.config_file"
    case advancedEditLua = "(action) general.advanced.edit_lua"
    case advancedDiscardArrangement =
        "(action) general.advanced.discard_arrangement"
    case advancedResetAll = "(action) general.advanced.reset_all"
    case advancedExportBackup =
        "(action) general.advanced.backup.export"
    case advancedRestoreBackup =
        "(action) general.advanced.backup.restore"
    case onboardingDiscoveryShown = "UserDefaults.onboarding.discoveryShown"
    case iconPickerRecents = "UserDefaults.IconPicker.recents"
    case onboardingOpenAtLogin = "onboarding.openAtLogin"
}

extension GeneralKey {
    var placement: SettingPlacement {
        switch self {
        case .language:
            return .row(.general, .appliesImmediately, .atRest)
        case .appearance:
            return .row(.general, .appliesImmediately, .atRest)
        case .startAtLogin:
            return .row(
                .general,
                .appliesImmediately,
                .atRest,
                gate: .runtimeAnyOf([
                    .loginItemServiceStatus,
                    .autoStartServiceLoaded,
                ])
            )
        case .about:
            return .row(.general, .about, .atRest)
        case .advancedConfigFile, .advancedEditLua,
            .advancedDiscardArrangement, .advancedResetAll,
            .advancedExportBackup, .advancedRestoreBackup:
            return .row(.general, .advanced, .showMore)
        case .onboardingDiscoveryShown, .iconPickerRecents:
            return .internalOnly
        case .onboardingOpenAtLogin:
            return .outsideSettings
        }
    }
}

extension GeneralKey {
    var text: SettingRowText {
        switch self {
        case .language:
            return .text("general.language.display")
        case .appearance:
            return .text("general.appearance")
        case .startAtLogin:
            return .text("general.login_item.start")
        case .about:
            return .text("general.about.title")
        case .advancedConfigFile:
            return .text("general.advanced.config_file")
        case .advancedEditLua:
            return .text(
                "general.advanced.edit_lua",
                caption: "general.advanced.edit_lua.caption"
            )
        case .advancedDiscardArrangement:
            return .text(
                "general.advanced.discard_arrangement",
                caption: "general.advanced.discard_arrangement.caption",
                help: "general.advanced.discard_arrangement.help"
            )
        case .advancedResetAll:
            return .text(
                "general.advanced.reset_all",
                caption: "general.advanced.reset_all.caption",
                help: "general.advanced.reset_all.help"
            )
        case .advancedExportBackup:
            return .text(
                "general.advanced.backup.export",
                caption: "general.advanced.backup.export.caption",
                help: "general.advanced.backup.export.help"
            )
        case .advancedRestoreBackup:
            return .text(
                "general.advanced.backup.restore",
                caption: "general.advanced.backup.restore.caption",
                help: "general.advanced.backup.restore.help"
            )
        case .onboardingDiscoveryShown, .iconPickerRecents,
            .onboardingOpenAtLogin:
            return .none
        }
    }
}
