/// App-wide General rows: language, login item, About,
/// Advanced maintenance actions, app-internal UserDefaults.

enum GeneralKey: String, CaseIterable, Hashable {
    case language = "UserDefaults.language"
    case startAtLogin = "AutoStartManager (no stored pref)"
    case about = "(readonly) general.about"
    case advancedConfigFile = "(readonly) general.advanced.config_file"
    case advancedEditLua = "(action) general.advanced.edit_lua"
    case advancedDiscardArrangement =
        "(action) general.advanced.discard_arrangement"
    case advancedResetAll = "(action) general.advanced.reset_all"
    case onboardingDiscoveryShown = "UserDefaults.onboarding.discoveryShown"
    case iconPickerRecents = "UserDefaults.IconPicker.recents"
    case onboardingOpenAtLogin = "onboarding.openAtLogin"
}

extension GeneralKey {
    var placement: SettingPlacement {
        switch self {
        case .language:
            return .row(.general, .language, .atRest)
        case .startAtLogin:
            return .row(
                .general,
                .login,
                .atRest,
                gate: .runtime(.loginItemServiceStatus)
            )
        case .about:
            return .row(.general, .about, .atRest)
        case .advancedConfigFile, .advancedEditLua,
            .advancedDiscardArrangement, .advancedResetAll:
            return .row(.general, .advanced, .showMore)
        case .onboardingDiscoveryShown:
            return .luaOnly
        case .iconPickerRecents:
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
        case .onboardingDiscoveryShown, .iconPickerRecents,
            .onboardingOpenAtLogin:
            return .none
        }
    }
}
