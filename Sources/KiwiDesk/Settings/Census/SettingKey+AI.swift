/// AI rows (#1685): copy buttons only, nothing stored. A row is
/// an `(action)` census entry so search reaches it.
enum AIKey: String, CaseIterable, Hashable {
    case addToClaudeDesktop = "(action) ai.setup.desktop"
    case copySetupPrompt = "(action) ai.setup.coding_apps"
    case promptLook = "(action) ai.prompt.look"
    case promptMigrate = "(action) ai.prompt.migrate"
    case promptAppRules = "(action) ai.prompt.app_rules"
    case promptSpaces = "(action) ai.prompt.spaces"
}

extension AIKey {
    var placement: SettingPlacement {
        switch self {
        case .addToClaudeDesktop, .copySetupPrompt:
            return .row(
                .ai,
                .aiSetup,
                .atRest,
                gate: .runtime(.runningCopyTranslocated)
            )
        case .promptLook, .promptMigrate, .promptAppRules,
            .promptSpaces:
            return .row(.ai, .readyMadePrompts, .atRest)
        }
    }

    var text: SettingRowText {
        switch self {
        case .copySetupPrompt:
            return .text(
                labelKey,
                caption: labelKey + ".caption",
                help: labelKey + ".help"
            )
        case .addToClaudeDesktop, .promptLook, .promptMigrate,
            .promptAppRules, .promptSpaces:
            return .text(labelKey, caption: labelKey + ".caption")
        }
    }

    /// The `L()` key of the row's title.
    var labelKey: String {
        String(rawValue.dropFirst("(action) ".count))
    }
}
