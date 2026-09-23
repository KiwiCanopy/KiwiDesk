/// The app-rules (`GuiConfig` rules) slice of the census.

enum AppRulesKey: String, CaseIterable, Hashable {
    case appRules = "config.appRules[app]"
    case floatRules = "config.floatRules"
    case floatRulesPattern = "config.floatRules[].pattern"
    case ignoreRules = "config.ignoreRules"
    case appRulesAddSpace = "(action) app_rules.add_space"
    case appRulesAddFloat = "(action) app_rules.add_float"
    case appRulesDelete = "(action) app_rules.delete"
}

extension AppRulesKey {
    var placement: SettingPlacement {
        switch self {
        case .appRules:
            // Gated by the SPACE LIST, on another destination
            // (#1022). This row's one grey is "this profile
            // declares no Spaces", so `GateReasonPlacement`
            // resolves it `.remote` and the card owes a live
            // pointer naming where to fix it — which is the
            // `CrossReferenceRow` at its foot.
            //
            // It is NOT gated by the float facet, though that
            // facet does decide whether the clear button is
            // OFFERED: withholding an affordance is a surfacing
            // decision, not a grey, so declaring the float
            // setting here would hand the derivation a cause
            // that greys nothing and answer `.adjacent` for a
            // reason that lives one destination away (code
            // review, 2026-09-22).
            return .row(
                .appRules,
                .rulesPerApp,
                .atRest,
                gate: .setting(.spaces(.spaceList))
            )
        case .floatRules, .appRulesAddSpace, .appRulesAddFloat,
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
            // The Space facet's name, drawn as the column
            // heading and spoken as the menu's own — one key, both
            // channels, since #1022 retired the checkbox that used
            // to carry a second label beside it.
            return .text("app_rules.space")
        case .floatRules:
            // The help key is still this row's, and still the one
            // copy of the float explanation — but since #1022 it
            // renders in the section's `?` rather than as a
            // tooltip on this row, a hover being reachable by
            // neither keyboard nor VoiceOver. The census keeps it
            // so the search index still finds the row by it.
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
        case .appRulesDelete:
            return .dynamic
        }
    }
}
