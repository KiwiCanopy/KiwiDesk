/// The app-rules (`GuiConfig` rules) slice of the census.

enum AppRulesKey: String, CaseIterable, Hashable {
    case appRules = "config.appRules[app]"
    case floatRules = "config.floatRules"
    case floatRulesPattern = "config.floatRules[].pattern"
    case ignoreRules = "config.ignoreRules"
    case appRulesAddSpace = "(action) app_rules.add_space"
    case appRulesAddFloat = "(action) app_rules.add_float"
    case spaceRuleDelete = "(action) app_rules.space.delete"
    case floatRuleDelete = "(action) app_rules.float.delete"
}

extension AppRulesKey {
    /// Two containers since #1608, one per store: a Space rule
    /// and a float rule are separate lists.
    var placement: SettingPlacement {
        switch self {
        case .appRules:
            // Gated by the SPACE LIST, on another destination
            // (#1022), so `GateReasonPlacement` resolves it
            // `.remote` and the card owes the `CrossReferenceRow`
            // at its foot.
            return .row(
                .appRules,
                .spaceRules,
                .atRest,
                gate: .setting(.spaces(.spaceList))
            )
        case .appRulesAddSpace, .spaceRuleDelete:
            return .row(.appRules, .spaceRules, .atRest)
        case .floatRules, .appRulesAddFloat, .floatRuleDelete:
            return .row(.appRules, .floatRules, .atRest)
        case .floatRulesPattern:
            // An OFFER until the user matches a title (#1022):
            // withheld in Simple until some row carries a
            // pattern, and at rest in BOTH modes once one does.
            return .row(
                .appRules,
                .floatRules,
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
            // The Space menu's spoken name; no visible label
            // draws it, the list title saying what the column is.
            return .text("app_rules.space")
        case .floatRules:
            // The help key renders in the Float card's `?`, not
            // as a tooltip, a hover being reachable by neither
            // keyboard nor VoiceOver; the census keeps it so the
            // search index still finds the row by it.
            return .text(
                "app_rules.float",
                help: "app_rules.float.help"
            )
        case .floatRulesPattern:
            return .dynamic
        case .ignoreRules:
            return .none
        case .appRulesAddSpace:
            return .text("app_rules.add_space")
        case .appRulesAddFloat:
            return .text("app_rules.add_float")
        case .spaceRuleDelete, .floatRuleDelete:
            return .dynamic
        }
    }
}
