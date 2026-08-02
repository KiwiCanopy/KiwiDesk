/// Spaces: the space list, per-space assignments and
/// override reset actions.

enum SpacesKey: String, CaseIterable, Hashable {
    case spaceIcon = "settings.spaceIcons[space]"
    case spaceList = "config.spaces"
    case spacesName = "config.spaces[].name"
    case spaceModes = "config.spaceModes[space]"
    case fallbackSpace = "config.fallbackSpace"
    case spaceOverrideResetActive = "(action) space_override.reset_active"
    case spaceOverrideResetAll = "(action) space_override.reset_all"
    case spacesDelete = "(action) spaces.delete"
}

extension SpacesKey {
    var placement: SettingPlacement {
        switch self {
        case .spaceIcon, .spaceList, .spacesName, .spaceModes, .spacesDelete:
            return .row(.spacesAndLayouts, .spaceList, .atRest)
        case .fallbackSpace:
            return .row(.spacesAndLayouts, .spaceList, .showMore)
        case .spaceOverrideResetActive:
            // Dead while the space has nothing to reset
            // (SpaceOverrideRows+Footer).
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
        // reset_active's key is "Reset %1$@ Overrides" — the
        // layout name is interpolated per space, so dynamic.
        case .spaceIcon, .spaceList, .spacesName, .spaceModes,
            .fallbackSpace, .spaceOverrideResetActive:
            return .dynamic
        case .spaceOverrideResetAll:
            return .text("space_override.reset_all")
        case .spacesDelete:
            return .text("spaces.delete.help")
        }
    }
}
