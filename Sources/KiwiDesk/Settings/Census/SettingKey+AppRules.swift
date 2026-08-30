/// The app-rules (`GuiConfig` rules) slice of the census.

enum AppRulesKey: String, CaseIterable, Hashable {
    case appRules = "config.appRules[app]"
    case floatRules = "config.floatRules"
    case floatRulesPattern = "config.floatRules[].pattern"
    case ignoreRules = "config.ignoreRules"
    case appRulesAdd = "(action) app_rules.add"
    case appRulesDelete = "(action) app_rules.delete"
}

extension AppRulesKey {
    var placement: SettingPlacement {
        switch self {
        case .appRules, .floatRules, .appRulesAdd, .appRulesDelete:
            return .row(.appRules, .rulesPerApp, .atRest)
        case .floatRulesPattern:
            return .row(.appRules, .rulesPerApp, .showMore)
        case .ignoreRules:
            return .luaOnly
        }
    }
}

extension AppRulesKey {
    var text: SettingRowText {
        switch self {
        case .appRules:
            return .text("app_rules.space")
        case .floatRules:
            return .text("app_rules.float", help: "app_rules.float.help")
        case .floatRulesPattern:
            return .dynamic
        case .ignoreRules:
            return .none
        case .appRulesAdd:
            return .text("app_rules.add_rule")
        case .appRulesDelete:
            return .dynamic
        }
    }
}
