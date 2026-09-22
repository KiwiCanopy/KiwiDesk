/// The app-rules (`GuiConfig` rules) slice of the census.

enum AppRulesKey: String, CaseIterable, Hashable {
    case appRules = "config.appRules[app]"
    case floatRules = "config.floatRules"
    case floatRulesPattern = "config.floatRules[].pattern"
    case ignoreRules = "config.ignoreRules"
    case appRulesAddPin = "(action) app_rules.add_pin"
    case appRulesAddFloat = "(action) app_rules.add_float"
    case appRulesDelete = "(action) app_rules.delete"
}

extension AppRulesKey {
    var placement: SettingPlacement {
        switch self {
        case .appRules:
            // Gated BY the float facet beside it (#1022): tiling
            // holds the pin engaged, because a rule that neither
            // floats nor pins says nothing. The cause is one
            // control to its left in the same row, which is what
            // makes this `.adjacent` and spares every row an
            // inline sentence it would stamp per app.
            return .row(
                .appRules,
                .rulesPerApp,
                .atRest,
                gate: .setting(.appRules(.floatRules))
            )
        case .floatRules, .appRulesAddPin, .appRulesAddFloat,
            .appRulesDelete:
            return .row(.appRules, .rulesPerApp, .atRest)
        case .floatRulesPattern:
            // An OFFER until the user matches a title (#1022):
            // matching windows by a title fragment is power-user
            // work, so the choice is withheld in Simple until
            // some row carries a pattern, and at rest in BOTH
            // modes once one does.
            return .row(
                .appRules,
                .rulesPerApp,
                .immediate,
                gate: .runtime(.titlePatternsExist)
            )
        case .ignoreRules:
            return .luaOnly
        }
    }
}

extension AppRulesKey {
    var text: SettingRowText {
        switch self {
        case .appRules:
            // The Space facet's name, which is what a diff row
            // and a search hit want — `app_rules.pin` labels the
            // CHECKBOX that writes the same setting, and is
            // authored at its own call sites.
            return .text("app_rules.space")
        case .floatRules:
            return .text("app_rules.float", help: "app_rules.float.help")
        case .floatRulesPattern:
            return .dynamic
        case .ignoreRules:
            return .none
        case .appRulesAddPin:
            return .text("app_rules.add_pin")
        case .appRulesAddFloat:
            return .text("app_rules.add_float")
        case .appRulesDelete:
            return .dynamic
        }
    }
}
