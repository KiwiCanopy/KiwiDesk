/// Spaces census slice: space list, assignments, and override reset actions.

enum SpacesKey: String, CaseIterable, Hashable {
    case spaceIcon = "settings.spaceIcons[space]"
    case spaceList = "config.spaces"
    case spacesName = "config.spaces[].name"
    case spaceModes = "config.spaceModes[space]"
    case fallbackSpace = "config.fallbackSpace"
    case spaceOverrideResetActive = "(action) space_override.reset_active"
    case spaceOverrideResetAll = "(action) space_override.reset_all"
    case spacesDelete = "(action) spaces.delete"
    /// A temporary Space's add button (#1790). Its grey — no
    /// profile file live — is live state, so a wiring predicate.
    case spacesAddToProfile = "(action) spaces.add_to_profile"
}

extension SpacesKey {
    var placement: SettingPlacement {
        switch self {
        case .spaceIcon, .spaceList, .spacesName, .spaceModes, .spacesDelete,
            .spacesAddToProfile:
            return .row(.spacesAndLayouts, .spaceList, .atRest)
        case .fallbackSpace:
            return .row(.spacesAndLayouts, .spaceList, .showMore)
        case .spaceOverrideResetActive:
            // Inactive when the space has no overrides (#678).
            return .row(
                .spacesAndLayouts,
                .perSpaceOverrides,
                .atRest,
                gate: .runtime(.spaceHasNoOverrides)
            )
        case .spaceOverrideResetAll:
            return .row(.spacesAndLayouts, .perSpaceOverrides, .atRest)
        }
    }
}

extension SpacesKey {
    var text: SettingRowText {
        switch self {
        case .spaceIcon, .spaceList, .spacesName, .spaceModes,
            .fallbackSpace, .spaceOverrideResetActive:
            return .dynamic
        case .spaceOverrideResetAll:
            return .text("space_override.reset_all")
        case .spacesDelete:
            return .text("spaces.delete.help")
        case .spacesAddToProfile:
            return .text("spaces.add_to_profile")
        }
    }
}
